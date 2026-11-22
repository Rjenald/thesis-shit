<?php
declare(strict_types=1);

/**
 * The account endpoints, exercised against a real database.
 *
 * SQLite rather than MySQL, so this runs anywhere PHP does and leaves no
 * state behind. The queries in auth.php are deliberately plain enough to
 * be portable; what is being tested here is the behaviour around them --
 * status codes, messages, what reaches the response and what does not.
 *
 * Run:  php backend/php_api/tests/auth_test.php
 *
 * It does NOT prove the deployment works: .htaccess rewriting and the
 * MySQL connection can only be checked on the server. backend/php_api/README.md
 * lists what to verify there.
 */

require __DIR__ . '/../db.php';
require __DIR__ . '/../auth.php';

$passed = 0;
$failures = [];

function check(string $what, bool $ok, string $detail = ''): void
{
    global $passed, $failures;
    if ($ok) {
        $passed++;
        return;
    }
    $failures[] = $what . ($detail === '' ? '' : " -- $detail");
}

function same(string $what, $expected, $actual): void
{
    check(
        $what,
        $expected === $actual,
        'expected ' . var_export($expected, true)
        . ', got ' . var_export($actual, true)
    );
}

/**
 * A fresh database per case. The admin flag and both hash dialects are
 * seeded, because the table on the server contains rows written by PHP's
 * password_hash() and, since the Python API went in, rows written by
 * Python's bcrypt as well.
 */
function fresh_db(): PDO
{
    $pdo = new PDO('sqlite::memory:', null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $pdo->exec(
        'CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            first_name TEXT,
            last_name TEXT,
            is_admin INTEGER NOT NULL DEFAULT 0
        )'
    );

    $insert = $pdo->prepare(
        'INSERT INTO users (username, password, email, first_name, last_name, is_admin)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    // Written by PHP: the $2y$ dialect, as the pre-existing accounts are.
    $insert->execute([
        'singer', password_hash('secret123', PASSWORD_BCRYPT),
        'singer@example.com', 'Maria', 'Santos', 0,
    ]);
    // Written by Python's bcrypt: the $2b$ dialect. A real hash of
    // 'secret123', generated with backend/venv's bcrypt -- not a prefix
    // swap, which would not catch a genuine incompatibility.
    $insert->execute([
        'pythonmade',
        '$2b$12$lUzeq8kpsyDniOEFrmnbxeeLDYjxq9s91vTPPl7iY99UxSQSrE7Ea',
        'python@example.com', null, null, 0,
    ]);
    $insert->execute([
        'boss', password_hash('bosspass', PASSWORD_BCRYPT),
        'boss@example.com', 'Admin', 'User', 1,
    ]);
    return $pdo;
}

// ---------------------------------------------------------------- health

$db = fresh_db();
$res = huni_handle('GET', '/auth/health', null, $db);
same('health status', 200, $res['status']);
same('health reports ok', 'ok', $res['body']['status']);
same('health counts the rows', 3, $res['body']['users']);
check(
    'health names the database',
    array_key_exists('database', $res['body']),
    'the app shows this when login fails'
);

$res = huni_handle('POST', '/auth/health', [], $db);
same('health rejects POST', 405, $res['status']);

// ----------------------------------------------------------------- login

$res = huni_handle('POST', '/auth/login', [
    'username' => 'singer', 'password' => 'secret123',
], $db);
same('login succeeds', 200, $res['status']);
same('login sets ok', true, $res['body']['ok']);
same('login returns the username', 'singer', $res['body']['user']['username']);
same('login maps first_name', 'Maria', $res['body']['user']['firstName']);
same('login maps last_name', 'Santos', $res['body']['user']['lastName']);
same('a plain user is not an admin', false, $res['body']['user']['isAdmin']);

// The contract the Flutter AuthResult.success factory reads. A key renamed
// here is a field silently lost in the app, not an error.
same(
    'the user object has exactly the keys the app reads',
    ['id', 'username', 'email', 'firstName', 'lastName', 'isAdmin'],
    array_keys($res['body']['user'])
);
check('id is an int', is_int($res['body']['user']['id']));
check(
    'isAdmin is a JSON boolean, not 0/1',
    str_contains(json_encode($res['body']['user']), '"isAdmin":false'),
    json_encode($res['body']['user'])
);
check(
    'the password hash never leaves the server',
    !str_contains(json_encode($res['body']), '$2'),
    json_encode($res['body'])
);

// The reason this port is safe to make: the hashes already in the table
// came from both languages, and PHP has to read both.
$res = huni_handle('POST', '/auth/login', [
    'username' => 'pythonmade', 'password' => 'secret123',
], $db);
same('PHP verifies a hash written by Python bcrypt', 200, $res['status']);

$res = huni_handle('POST', '/auth/login', [
    'username' => 'singer@example.com', 'password' => 'secret123',
], $db);
same('login accepts the email address too', 200, $res['status']);

$res = huni_handle('POST', '/auth/login', [
    'username' => '  singer  ', 'password' => 'secret123',
], $db);
same('a username pasted with spaces still works', 200, $res['status']);

// Wrong password and unknown account must be indistinguishable, or the
// endpoint tells an attacker which usernames exist.
$wrongPass = huni_handle('POST', '/auth/login', [
    'username' => 'singer', 'password' => 'nope',
], $db);
$noSuchUser = huni_handle('POST', '/auth/login', [
    'username' => 'ghost', 'password' => 'nope',
], $db);
same('wrong password is 401', 401, $wrongPass['status']);
same('unknown user is 401', 401, $noSuchUser['status']);
same(
    'wrong password and unknown user are indistinguishable',
    $wrongPass,
    $noSuchUser
);
same(
    'the 401 message matches the Python API word for word',
    'Invalid username or password',
    $wrongPass['body']['detail']
);

// A password that is right for a different account must not work here.
$res = huni_handle('POST', '/auth/login', [
    'username' => 'singer', 'password' => 'bosspass',
], $db);
same("another account's password is rejected", 401, $res['status']);

// Parameterised queries, demonstrated rather than asserted by reading the
// source: this returns every row if the username is interpolated.
$res = huni_handle('POST', '/auth/login', [
    'username' => "' OR 1=1 --", 'password' => 'secret123',
], $db);
same('a SQL injection attempt just fails to log in', 401, $res['status']);

$res = huni_handle('POST', '/auth/login', ['username' => 'singer'], $db);
same('a missing password is 400, not 401', 400, $res['status']);
$res = huni_handle('POST', '/auth/login', ['password' => 'secret123'], $db);
same('a missing username is 400', 400, $res['status']);
$res = huni_handle('POST', '/auth/login', [
    'username' => 'singer', 'password' => '',
], $db);
same('an empty password is 400', 400, $res['status']);

// ----------------------------------------------------------- admin login

$res = huni_handle('POST', '/auth/login', [
    'username' => 'boss', 'password' => 'bosspass', 'requireAdmin' => true,
], $db);
same('an admin can sign in to the admin screen', 200, $res['status']);
same('isAdmin comes back true', true, $res['body']['user']['isAdmin']);

$res = huni_handle('POST', '/auth/login', [
    'username' => 'singer', 'password' => 'secret123', 'requireAdmin' => true,
], $db);
same('a non-admin is refused the admin screen', 403, $res['status']);
same(
    'the 403 message matches the Python API',
    'This account does not have admin access',
    $res['body']['detail']
);

// The order matters: a wrong password on a non-admin account must look
// like a wrong password, not reveal that the account lacks admin rights.
$res = huni_handle('POST', '/auth/login', [
    'username' => 'singer', 'password' => 'wrong', 'requireAdmin' => true,
], $db);
same('credentials are checked before admin rights', 401, $res['status']);

$res = huni_handle('POST', '/auth/login', [
    'username' => 'boss', 'password' => 'bosspass',
], $db);
same('an admin can also use the normal login', 200, $res['status']);

// The client cannot grant itself anything by sending the flag.
$res = huni_handle('POST', '/auth/login', [
    'username' => 'singer', 'password' => 'secret123', 'isAdmin' => true,
], $db);
same('a client-supplied isAdmin is ignored', false, $res['body']['user']['isAdmin']);

// ------------------------------------------------------------- register

$db = fresh_db();
$res = huni_handle('POST', '/auth/register', [
    'username' => 'newbie',
    'password' => 'pass1234',
    'email' => 'newbie@example.com',
    'firstName' => 'New',
    'lastName' => 'Singer',
], $db);
same('register succeeds', 200, $res['status']);
same('register returns the new username', 'newbie', $res['body']['user']['username']);
same('register echoes the first name', 'New', $res['body']['user']['firstName']);
same('a new account is not an admin', false, $res['body']['user']['isAdmin']);
same(
    'the registered user object has the same keys as login',
    ['id', 'username', 'email', 'firstName', 'lastName', 'isAdmin'],
    array_keys($res['body']['user'])
);

$stored = $db->query("SELECT * FROM users WHERE username = 'newbie'")->fetch();
check('the row was really inserted', $stored !== false);
check(
    'the password was hashed, not stored as typed',
    $stored['password'] !== 'pass1234',
    'a plain-text password in the table'
);
check(
    'the stored hash is bcrypt',
    str_starts_with((string) $stored['password'], '$2'),
    (string) $stored['password']
);
check(
    'the new account can sign in with the password it registered with',
    huni_handle('POST', '/auth/login', [
        'username' => 'newbie', 'password' => 'pass1234',
    ], $db)['status'] === 200
);

// Round trip in the other direction: the Python API must be able to read
// what PHP writes, which it does by rewriting the $2y$ tag. Confirm the
// tag is the one that shim expects.
check(
    'PHP writes the $2y$ dialect the Python shim handles',
    str_starts_with((string) $stored['password'], '$2y$'),
    (string) $stored['password']
);

$res = huni_handle('POST', '/auth/register', [
    'username' => 'singer', 'password' => 'pass1234', 'email' => 'fresh@example.com',
], $db);
same('a taken username is 409', 409, $res['status']);
same('and says which field', 'Username is already taken', $res['body']['detail']);

$res = huni_handle('POST', '/auth/register', [
    'username' => 'fresh', 'password' => 'pass1234', 'email' => 'singer@example.com',
], $db);
same('a taken email is 409', 409, $res['status']);
same('and says which field', 'Email is already taken', $res['body']['detail']);

$res = huni_handle('POST', '/auth/register', [
    'username' => 'fresh', 'password' => 'pass1234', 'email' => 'not-an-email',
], $db);
same('a malformed email is 400', 400, $res['status']);
same(
    'the email message matches the Python API',
    'Enter a valid email address',
    $res['body']['detail']
);

foreach (['no-at.example.com', 'two@@example.com', 'no@domain', 'spa ce@example.com'] as $bad) {
    $res = huni_handle('POST', '/auth/register', [
        'username' => 'fresh', 'password' => 'pass1234', 'email' => $bad,
    ], $db);
    same("'$bad' is rejected as an email", 400, $res['status']);
}

$res = huni_handle('POST', '/auth/register', [
    'username' => 'fresh', 'password' => 'abc', 'email' => 'fresh@example.com',
], $db);
same('a password under four characters is 400', 400, $res['status']);

$res = huni_handle('POST', '/auth/register', [
    'username' => 'ab', 'password' => 'pass1234', 'email' => 'fresh@example.com',
], $db);
same('a username under three characters is 400', 400, $res['status']);
same(
    'and the message says what the limit is',
    'Username must be at least 3 characters',
    $res['body']['detail']
);

$res = huni_handle('POST', '/auth/register', [
    'username' => str_repeat('x', 101),
    'password' => 'pass1234',
    'email' => 'fresh@example.com',
], $db);
same('an over-long username is 400, not a truncated row', 400, $res['status']);

$res = huni_handle('POST', '/auth/register', [
    'username' => 'spaced', 'password' => 'pass1234',
    'email' => 'spaced@example.com', 'firstName' => '   ', 'lastName' => '',
], $db);
same('blank names are accepted', 200, $res['status']);
same('a blank first name is stored as null', null, $res['body']['user']['firstName']);
same('a blank last name is stored as null', null, $res['body']['user']['lastName']);

$res = huni_handle('POST', '/auth/register', [
    'username' => 'nonames', 'password' => 'pass1234', 'email' => 'nn@example.com',
], $db);
same('names are optional', 200, $res['status']);
same('a missing first name is null', null, $res['body']['user']['firstName']);

// --------------------------------------------------------------- routing

same(
    'an unknown path is 404',
    404,
    huni_handle('GET', '/auth/whatever', null, $db)['status']
);
same(
    'the root is 404 rather than a blank 200',
    404,
    huni_handle('GET', '/', null, $db)['status']
);
same(
    'a trailing slash still routes',
    200,
    huni_handle('GET', '/auth/health/', null, $db)['status']
);
same(
    'a lowercase method still routes',
    200,
    huni_handle('get', '/auth/health', null, $db)['status']
);
same(
    'GET on login is 405',
    405,
    huni_handle('GET', '/auth/login', null, $db)['status']
);
same(
    'POST with no body at all is 400',
    400,
    huni_handle('POST', '/auth/login', null, $db)['status']
);

// Every failure the app can receive must carry `detail`, because that is
// the only field it shows the user.
foreach ([
    ['POST', '/auth/login', ['username' => 'singer', 'password' => 'no']],
    ['POST', '/auth/login', ['username' => 'singer']],
    ['POST', '/auth/register', ['username' => 'ab', 'password' => 'pass1234', 'email' => 'a@b.co']],
    ['GET', '/auth/nope', null],
] as [$method, $path, $payload]) {
    $res = huni_handle($method, $path, $payload, $db);
    check(
        "$method $path carries a detail message",
        is_string($res['body']['detail'] ?? null)
        && $res['body']['detail'] !== '',
        json_encode($res['body'])
    );
    check(
        "$method $path does not claim ok",
        ($res['body']['ok'] ?? false) !== true
    );
}

// ----------------------------------------------------------------- done

echo "passed: $passed\n";
if ($failures) {
    echo 'FAILED: ' . count($failures) . "\n";
    foreach ($failures as $f) {
        echo "  - $f\n";
    }
    exit(1);
}
echo "all green\n";
