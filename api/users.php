<?php
// users.php - User management
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($method) {
    case 'GET':
        $stmt = $conn->query("
            SELECT id, username, email, name, surname, role, 
                   two_factor_enabled as twoFactorEnabled,
                   two_factor_secret as twoFactorSecret,
                   created_at as createdAt
            FROM users
            ORDER BY created_at DESC
        ");
        sendResponse($stmt->fetchAll(PDO::FETCH_ASSOC));
        break;
        
    case 'POST':
        try {
            $password_hash = password_hash($data['password'] ?? 'password123', PASSWORD_BCRYPT);
            
            // Check if user exists
            $stmt = $conn->prepare("SELECT id FROM users WHERE username = ?");
            $stmt->execute([$data['username']]);
            
            if ($stmt->fetch()) {
                // Update existing user
                $sql = "UPDATE users SET email=?, name=?, surname=?, role=?, 
                        two_factor_enabled=?, two_factor_secret=?";
                $params = [
                    $data['email'],
                    $data['name'] ?? '',
                    $data['surname'] ?? '',
                    $data['role'] ?? 'user',
                    $data['twoFactorEnabled'] ?? false,
                    $data['twoFactorSecret'] ?? null
                ];
                
                if (!empty($data['password'])) {
                    $sql .= ", password=?";
                    $params[] = $password_hash;
                }
                
                $sql .= " WHERE username=?";
                $params[] = $data['username'];
                
                $stmt = $conn->prepare($sql);
                $stmt->execute($params);
                sendResponse(['success' => true, 'action' => 'updated']);
            } else {
                // Insert new user
                $stmt = $conn->prepare("
                    INSERT INTO users (username, password, email, name, surname, role, 
                                     two_factor_enabled, two_factor_secret)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ");
                $stmt->execute([
                    $data['username'],
                    $password_hash,
                    $data['email'],
                    $data['name'] ?? '',
                    $data['surname'] ?? '',
                    $data['role'] ?? 'user',
                    $data['twoFactorEnabled'] ?? false,
                    $data['twoFactorSecret'] ?? null
                ]);
                sendResponse(['success' => true, 'id' => $conn->lastInsertId(), 'action' => 'created']);
            }
        } catch (PDOException $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'PUT':
        try {
            $sql = "UPDATE users SET email=?, name=?, surname=?, role=?, 
                    two_factor_enabled=?, two_factor_secret=?";
            $params = [
                $data['email'],
                $data['name'] ?? '',
                $data['surname'] ?? '',
                $data['role'],
                $data['twoFactorEnabled'] ?? false,
                $data['twoFactorSecret'] ?? null
            ];
            
            if (!empty($data['password'])) {
                $sql .= ", password=?";
                $params[] = password_hash($data['password'], PASSWORD_BCRYPT);
            }
            
            $sql .= " WHERE username=?";
            $params[] = $data['username'];
            
            $stmt = $conn->prepare($sql);
            $stmt->execute($params);
            sendResponse(['success' => true]);
        } catch (PDOException $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'DELETE':
        try {
            $stmt = $conn->prepare("DELETE FROM users WHERE username = ? AND username != 'admin'");
            $stmt->execute([$data['username']]);
            
            if ($stmt->rowCount() > 0) {
                sendResponse(['success' => true]);
            } else {
                sendResponse(['error' => 'Cannot delete admin user or user not found'], 400);
            }
        } catch (PDOException $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    default:
        sendResponse(['error' => 'Method not allowed'], 405);
}
?>
