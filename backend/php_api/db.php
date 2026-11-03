<?php
declare(strict_types=1);

/**
 * The one place that holds database credentials.
 *
 * Mirrors the connection half of backend/auth_api.py: a single handle, and
 * a 503 with a legible reason when the database cannot be reached, because
 * the app shows that reason to the user. A login failure and a database
 * outage look identical from a phone otherwise.
 */

/** Thrown when the database is unreachable; index.php turns it into a 503. */
class HuniDatabaseDown extends RuntimeException
{
}

function huni_config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }
    $path = __DIR__ . '/config.php';
    if (!is_file($path)) {
        throw new HuniDatabaseDown(
            'config.php is missing on the server — copy config.example.php '
            . 'to config.php and fill in the database details.'
        );
    }
    $config = require $path;
    return $config;
}

/**
 * Lets the test suite hand the handlers a SQLite database instead.
 * Returns the previous handle so a test can put things back.
 */
function huni_set_pdo(?PDO $pdo): ?PDO
{
    static $current = null;
    $previous = $current;
    if (func_num_args() > 0) {
        $current = $pdo;
    }
    return $previous;
}

function huni_pdo(): PDO
{
    static $pdo = null;

    // An injected handle always wins, and is not cached, so tests can swap
    // databases between cases.
    $injected = huni_set_pdo();
    if ($injected instanceof PDO) {
        return $injected;
    }
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $c = huni_config();
    $dsn = sprintf(
        'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
        $c['host'],
        (int) $c['port'],
        $c['name']
    );
    try {
        $pdo = new PDO($dsn, $c['user'], $c['pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_TIMEOUT => 5,
        ]);
    } catch (PDOException $exc) {
        // Surfaced rather than swallowed: on Hostinger the usual causes are
        // a wrong database name (it is prefixed with the account id) or a
        // password that was reset in hPanel.
        throw new HuniDatabaseDown(sprintf(
            'Cannot reach MySQL at %s/%s — check the host, database name '
            . 'and password in config.php. (%s)',
            $c['host'],
            $c['name'],
            $exc->getMessage()
        ));
    }
    return $pdo;
}
