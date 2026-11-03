<?php
declare(strict_types=1);

/**
 * The three account endpoints, as plain functions over a PDO handle.
 *
 * A port of backend/auth_api.py, kept behaviour-for-behaviour identical:
 * same paths, same status codes, same JSON shapes, and the same error
 * strings — the Flutter app shows `detail` to the user verbatim, so a
 * reworded message is a user-visible change. backend/test_php_auth_parity.py
 * asserts the two files have not drifted apart.
 *
 * Why PHP at all: Hostinger's shared plans run PHP and MySQL and nothing
 * else. Running the API on the same host as the database also means the
 * app never needs remote MySQL access, so the plan tier that reportedly
 * gates that feature does not matter.
 *
 * The handlers take their PDO as an argument rather than reaching for a
 * global, so the test suite can hand them a SQLite database.
 */

/** Everything about a user except the password hash. */
function huni_public_user(array $row): array
{
    return [
        'id' => isset($row['id']) ? (int) $row['id'] : null,
        'username' => $row['username'] ?? null,
        'email' => $row['email'] ?? null,
        'firstName' => $row['first_name'] ?? null,
        'lastName' => $row['last_name'] ?? null,
        // Decided by the database, never by the client. The app asks to
        // sign in as admin; only this flag grants it.
        'isAdmin' => (bool) ($row['is_admin'] ?? 0),
    ];
}

/**
 * Verifies against the bcrypt hashes already in the table.
 *
 * No prefix rewriting here, unlike the Python side: those rows were
 * written by password_hash() in the first place, and password_verify()
 * also accepts the $2a$/$2b$ tags that rows created by the Python API
 * carry. Checked against a real Python-generated hash, not assumed.
 */
function huni_check_password(string $plain, ?string $stored): bool
{
    if ($stored === null || $stored === '') {
        return false;
    }
    return password_verify($plain, $stored);
}

function huni_hash_password(string $plain): string
{
    return password_hash($plain, PASSWORD_BCRYPT);
}

/** A handler result: an HTTP status and the body to encode as JSON. */
function huni_reply(int $status, array $body): array
{
    return ['status' => $status, 'body' => $body];
}

function huni_error(int $status, string $detail): array
{
    // FastAPI's HTTPException serialises as {"detail": ...}, and the app
    // reads exactly that key.
    return huni_reply($status, ['detail' => $detail]);
}

/**
 * Pulls a required string field out of a decoded JSON body.
 *
 * Where FastAPI would answer 422 with a list of pydantic errors — which
 * the app cannot render, so it degrades to "Something went wrong (422)" —
 * this answers 400 with a sentence worth showing someone.
 */
function huni_string_field(
    array $body,
    string $key,
    string $label,
    int $min,
    int $max
): array {
    $value = $body[$key] ?? null;
    if (!is_string($value)) {
        return ['error' => "$label is required"];
    }
    // Trimmed before measuring: a username of three spaces is not a
    // three-character username.
    $value = trim($value);
    $length = mb_strlen($value);
    if ($length < $min) {
        return ['error' => $min === 1
            ? "$label is required"
            : "$label must be at least $min characters"];
    }
    if ($length > $max) {
        return ['error' => "$label must be at most $max characters"];
    }
    return ['value' => $value];
}

function huni_health(PDO $pdo): array
{
    $name = 'unknown';
    try {
        $name = huni_config()['name'];
    } catch (HuniDatabaseDown $e) {
        // Under test there is no config.php and the handle was injected,
        // so the database name is simply not known here.
    }
    $n = (int) $pdo->query('SELECT COUNT(*) AS n FROM users')->fetch()['n'];
    return huni_reply(200, [
        'status' => 'ok',
        'database' => $name,
        'users' => $n,
    ]);
}

function huni_login(PDO $pdo, array $body): array
{
    $username = huni_string_field($body, 'username', 'Username', 1, 100);
    if (isset($username['error'])) {
        return huni_error(400, $username['error']);
    }
    // Neither trimmed nor length-checked beyond being present: a password
    // may legitimately begin or end with a space.
    $password = $body['password'] ?? null;
    if (!is_string($password) || $password === '') {
        return huni_error(400, 'Password is required');
    }

    $stmt = $pdo->prepare(
        'SELECT * FROM users WHERE username = ? OR email = ? LIMIT 1'
    );
    $stmt->execute([$username['value'], $username['value']]);
    $row = $stmt->fetch();

    // Same response whether the user is missing or the password is wrong,
    // so the endpoint cannot be used to enumerate valid usernames.
    if (!$row || !huni_check_password($password, $row['password'] ?? null)) {
        return huni_error(401, 'Invalid username or password');
    }

    $user = huni_public_user($row);

    // Checked only after the password is confirmed, so this cannot be used
    // to find out which accounts are admins.
    if (($body['requireAdmin'] ?? false) === true && !$user['isAdmin']) {
        return huni_error(403, 'This account does not have admin access');
    }

    return huni_reply(200, ['ok' => true, 'user' => $user]);
}

function huni_register(PDO $pdo, array $body): array
{
    foreach ([
        ['username', 'Username', 3, 100],
        ['email', 'Email', 3, 255],
    ] as [$key, $label, $min, $max]) {
        $field = huni_string_field($body, $key, $label, $min, $max);
        if (isset($field['error'])) {
            return huni_error(400, $field['error']);
        }
        $body[$key] = $field['value'];
    }

    $password = $body['password'] ?? null;
    if (!is_string($password) || mb_strlen($password) < 4) {
        return huni_error(400, 'Password must be at least 4 characters');
    }

    // The same expression as the Python side, which deliberately rejects
    // only the obviously malformed rather than trying to be RFC 5322.
    if (!preg_match('/^[^@\s]+@[^@\s]+\.[^@\s]+$/', $body['email'])) {
        return huni_error(400, 'Enter a valid email address');
    }

    $stmt = $pdo->prepare(
        'SELECT username, email FROM users WHERE username = ? OR email = ?'
    );
    $stmt->execute([$body['username'], $body['email']]);
    $clash = $stmt->fetch();
    if ($clash) {
        $field = ($clash['username'] ?? null) === $body['username']
            ? 'Username'
            : 'Email';
        return huni_error(409, "$field is already taken");
    }

    $insert = $pdo->prepare(
        'INSERT INTO users (username, password, email, first_name, last_name) '
        . 'VALUES (?, ?, ?, ?, ?)'
    );
    $insert->execute([
        $body['username'],
        huni_hash_password($password),
        $body['email'],
        huni_optional_name($body, 'firstName'),
        huni_optional_name($body, 'lastName'),
    ]);

    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$pdo->lastInsertId()]);
    $row = $stmt->fetch();

    return huni_reply(200, ['ok' => true, 'user' => huni_public_user($row)]);
}

/** firstName/lastName are optional, and an empty one is stored as NULL. */
function huni_optional_name(array $body, string $key): ?string
{
    $value = $body[$key] ?? null;
    if (!is_string($value)) {
        return null;
    }
    $value = trim($value);
    return $value === '' ? null : mb_substr($value, 0, 100);
}

/**
 * Routes one request. Returns ['status' => int, 'body' => array].
 *
 * Kept separate from index.php so tests can call it without a web server.
 */
function huni_handle(string $method, string $path, ?array $body, PDO $pdo): array
{
    $method = strtoupper($method);
    $path = '/' . trim($path, '/');

    if ($path === '/auth/health') {
        if ($method !== 'GET') {
            return huni_error(405, 'Use GET for /auth/health');
        }
        return huni_health($pdo);
    }

    $routes = [
        '/auth/login' => 'huni_login',
        '/auth/register' => 'huni_register',
    ];
    if (isset($routes[$path])) {
        if ($method !== 'POST') {
            return huni_error(405, "Use POST for $path");
        }
        if ($body === null) {
            return huni_error(400, 'Expected a JSON body');
        }
        return $routes[$path]($pdo, $body);
    }

    return huni_error(404, "No endpoint at $path");
}
