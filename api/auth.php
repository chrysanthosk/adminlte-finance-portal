<?php
// auth.php - Authentication endpoints
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$path = $_SERVER['PATH_INFO'] ?? '/';

$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($path) {
    case '/login':
        if ($method === 'POST') {
            $stmt = $conn->prepare("SELECT * FROM users WHERE username = ?");
            $stmt->execute([$data['username']]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($user && password_verify($data['password'], $user['password'])) {
                unset($user['password']);
                sendResponse([
                    'success' => true,
                    'user' => [
                        'username' => $user['username'],
                        'email' => $user['email'],
                        'name' => $user['name'],
                        'surname' => $user['surname'],
                        'role' => $user['role'],
                        'twoFactorEnabled' => (bool)$user['two_factor_enabled'],
                        'twoFactorSecret' => $user['two_factor_secret']
                    ]
                ]);
            } else {
                sendResponse(['success' => false, 'message' => 'Invalid credentials'], 401);
            }
        }
        break;
        
    case '/verify-2fa':
        if ($method === 'POST') {
            // In production, verify TOTP code here using libraries like:
            // https://github.com/PHPGangsta/GoogleAuthenticator
            // For now, accept any 6-digit code
            if (preg_match('/^\d{6}$/', $data['code'])) {
                sendResponse(['success' => true]);
            } else {
                sendResponse(['success' => false, 'message' => 'Invalid code'], 401);
            }
        }
        break;
        
    default:
        sendResponse(['error' => 'Endpoint not found'], 404);
}
?>
``*
