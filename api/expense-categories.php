<?php
// expense-categories.php - Expense categories configuration
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($method) {
    case 'GET':
        $stmt = $conn->query("
            SELECT id, name, is_active as active
            FROM expense_categories
            WHERE is_active = 1
            ORDER BY name
        ");
        sendResponse($stmt->fetchAll(PDO::FETCH_ASSOC));
        break;
        
    case 'POST':
        try {
            $stmt = $conn->prepare("INSERT INTO expense_categories (name) VALUES (?)");
            $stmt->execute([$data['name']]);
            sendResponse(['success' => true, 'id' => $conn->lastInsertId()]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'PUT':
        try {
            $stmt = $conn->prepare("UPDATE expense_categories SET name=? WHERE id=?");
            $stmt->execute([$data['name'], $data['id']]);
            sendResponse(['success' => true]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'DELETE':
        try {
            $stmt = $conn->prepare("UPDATE expense_categories SET is_active=0 WHERE id=?");
            $stmt->execute([$data['id']]);
            sendResponse(['success' => true]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
}
?>
