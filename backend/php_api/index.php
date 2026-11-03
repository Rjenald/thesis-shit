<?php
declare(strict_types=1);

/**
 * The only file the web server is meant to serve: everything under this
 * directory is routed here by .htaccess.
 *
 * It does three things and nothing else — work out the path, hand it to
 * huni_handle(), and write the result as JSON — so that the behaviour
 * worth testing lives in auth.php, which the test suite can call without
 * a web server.
 */

require __DIR__ . '/db.php';
require __DIR__ . '/auth.php';

/**
 * The request path, with this directory's prefix removed.
 *
 * Two shapes have to work. With mod_rewrite doing its job the request
 * arrives as /api/auth/login and SCRIPT_NAME is /api/index.php, so the
 * directory is stripped. Without it — a rewrite module turned off, or a
 * host that ignores .htaccess — /api/index.php/auth/login still reaches
 * this file with the rest in PATH_INFO. Supporting both means a broken
 * rewrite degrades to an uglier URL instead of a dead API.
 */
function huni_request_path(): string
{
    $pathInfo = $_SERVER['PATH_INFO'] ?? '';
    if ($pathInfo !== '') {
        return $pathInfo;
    }

    $uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
    $uri = is_string($uri) ? $uri : '/';

    $dir = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    $dir = rtrim($dir, '/');
    if ($dir !== '' && $dir !== '/' && str_starts_with($uri, $dir)) {
        $uri = substr($uri, strlen($dir));
    }
    if (str_starts_with($uri, '/index.php')) {
        $uri = substr($uri, strlen('/index.php'));
    }
    return $uri === '' ? '/' : $uri;
}

function huni_send(int $status, array $body): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    // The app is the only client, and it keeps nothing cached; a stale
    // 401 served from an intermediary would look like a wrong password.
    header('Cache-Control: no-store');
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// Decoded here rather than in the handlers so malformed JSON is one
// answer in one place. A body that is valid JSON but not an object (say a
// bare string) is treated as absent, which the router reports as such.
$body = null;
if ($method === 'POST' || $method === 'PUT' || $method === 'PATCH') {
    $raw = file_get_contents('php://input');
    if ($raw !== false && $raw !== '') {
        $decoded = json_decode($raw, true);
        $body = is_array($decoded) ? $decoded : null;
        if ($body === null) {
            huni_send(400, ['detail' => 'Could not read the request body as JSON']);
            return;
        }
    } else {
        $body = [];
    }
}

try {
    $result = huni_handle($method, huni_request_path(), $body, huni_pdo());
    huni_send($result['status'], $result['body']);
} catch (HuniDatabaseDown $down) {
    // 503 is what tells the app to say "server problem" instead of
    // wrongly telling someone their password is incorrect.
    huni_send(503, ['detail' => $down->getMessage()]);
} catch (Throwable $exc) {
    // Logged in full, reported in outline: the message can carry SQL and
    // table names, and this response goes to a phone.
    error_log('Huni auth API: ' . $exc);
    huni_send(500, ['detail' => 'The server hit an unexpected error.']);
}
