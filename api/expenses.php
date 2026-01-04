<?php
// expenses.php - Expense entries management
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($method) {
    case 'GET':
        $stmt = $conn->query("
            SELECT 
                ee.id,
                ee.date,
                ee.vendor,
                ee.amount,
                ee.payment_type_id as paymentTypeId,
                ee.category_id as categoryId,
                ee.cheque_no as chequeNo,
                ee.reason,
                ee.attachment,
                ee.created_by as createdBy,
                u.username as createdByUsername
            FROM expense_entries ee
            LEFT JOIN users u ON ee.created_by = u.id
            ORDER BY ee.date DESC, ee.created_at DESC
        ");
        sendResponse($stmt->fetchAll(PDO::FETCH_ASSOC));
        break;
        
    case 'POST':
        try {
            // Get user ID
            $stmt = $conn->prepare("SELECT id FROM users WHERE username = ?");
            $stmt->execute([$data['createdBy'] ?? 'admin']);
            $userId = $stmt->fetchColumn();
            
            $stmt = $conn->prepare("
                INSERT INTO expense_entries 
                (date, vendor, amount, payment_type_id, category_id, cheque_no, reason, attachment, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->execute([
                $data['date'],
                $data['vendor'],
                $data['amount'],
                $data['paymentTypeId'],
                $data['categoryId'],
                $data['chequeNo'] ?? null,
                $data['reason'] ?? null,
                $data['attachment'] ?? null,
                $userId
            ]);
            
            sendResponse(['success' => true, 'id' => $conn->lastInsertId()]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'PUT':
        try {
            $stmt = $conn->prepare("
                UPDATE expense_entries 
                SET date=?, vendor=?, amount=?, payment_type_id=?, category_id=?, 
                    cheque_no=?, reason=?, attachment=?
                WHERE id=?
            ");
            $stmt->execute([
                $data['date'],
                $data['vendor'],
                $data['amount'],
                $data['paymentTypeId'],
                $data['categoryId'],
                $data['chequeNo'] ?? null,
                $data['reason'] ?? null,
                $data['attachment'] ?? null,
                $data['id']
            ]);
            sendResponse(['success' => true]);
        } catch (Exception $e) {
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'DELETE':
        try {
            $stmt = $conn->prepare("DELETE FROM expense_entries WHERE id = ?");
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
