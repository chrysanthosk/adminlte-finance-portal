<?php
// income-methods.php - Income methods configuration
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($method) {
    case 'GET':
        $stmt = $conn->query("
            SELECT id, name, is_active as active, sort_order as sortOrder
            FROM income_methods
            WHERE is_active = 1
            ORDER BY sort_order, name
        ");
        sendResponse($stmt->fetchAll(PDO::FETCH_ASSOC));
        break;
        
    case 'POST':
        try {
            $stmt = $conn->prepare("INSERT INTO income_methods (name, sort_order) VALUES (?, ?)");
            $stmt->execute([$data['name'], $data['sortOrder'] ?? 999]);
            sendResponse(['success' => true, 'id' => $conn->lastInsertId()]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'PUT':
        try {
            $stmt = $conn->prepare("UPDATE income_methods SET name=? WHERE id=?");
            $stmt->execute([$data['name'], $data['id']]);
            sendResponse(['success' => true]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'DELETE':
        try {
            $stmt = $conn->prepare("UPDATE income_methods SET is_active=0 WHERE id=?");
            $stmt->execute([$data['id']]);
            sendResponse(['success' => true]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
}
?>
