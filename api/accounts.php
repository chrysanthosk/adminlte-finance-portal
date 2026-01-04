<?php
// accounts.php - Account management
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($method) {
    case 'GET':
        $stmt = $conn->query("
            SELECT id, name, type, currency, active
            FROM accounts
            ORDER BY name
        ");
        sendResponse($stmt->fetchAll(PDO::FETCH_ASSOC));
        break;
        
    case 'POST':
        try {
            $stmt = $conn->prepare("
                INSERT INTO accounts (name, type, currency, active)
                VALUES (?, ?, ?, ?)
            ");
            $stmt->execute([
                $data['name'],
                $data['type'],
                $data['currency'],
                $data['active'] ?? true
            ]);
            sendResponse(['success' => true, 'id' => $conn->lastInsertId()]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'PUT':
        try {
            $stmt = $conn->prepare("
                UPDATE accounts 
                SET name=?, type=?, currency=?, active=?
                WHERE id=?
            ");
            $stmt->execute([
                $data['name'],
                $data['type'],
                $data['currency'],
                $data['active'] ?? true,
                $data['id']
            ]);
            sendResponse(['success' => true]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'DELETE':
        try {
            $stmt = $conn->prepare("DELETE FROM accounts WHERE id = ?");
            $stmt->execute([$data['id']]);
            sendResponse(['success' => true]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    default:
        sendResponse(['error' => 'Method not allowed'], 405);
}
?>
