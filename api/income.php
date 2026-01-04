<?php
// income.php - Income entries management
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($method) {
    case 'GET':
        $stmt = $conn->query("
            SELECT 
                ie.id, 
                ie.date, 
                ie.notes, 
                ie.created_by as createdBy,
                u.username as createdByUsername,
                GROUP_CONCAT(CONCAT(iel.method_id, ':', iel.amount) SEPARATOR ';') as lines
            FROM income_entries ie
            LEFT JOIN income_entry_lines iel ON ie.id = iel.entry_id
            LEFT JOIN users u ON ie.created_by = u.id
            GROUP BY ie.id
            ORDER BY ie.date DESC, ie.created_at DESC
        ");
        
        $entries = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $lines = [];
            if ($row['lines']) {
                foreach (explode(';', $row['lines']) as $line) {
                    list($methodId, $amount) = explode(':', $line);
                    $lines[] = ['methodId' => (int)$methodId, 'amount' => (float)$amount];
                }
            }
            $row['lines'] = $lines;
            $entries[] = $row;
        }
        sendResponse($entries);
        break;
        
    case 'POST':
        $conn->beginTransaction();
        try {
            // Get user ID from username
            $stmt = $conn->prepare("SELECT id FROM users WHERE username = ?");
            $stmt->execute([$data['createdBy'] ?? 'admin']);
            $userId = $stmt->fetchColumn();
            
            $stmt = $conn->prepare("INSERT INTO income_entries (date, notes, created_by) VALUES (?, ?, ?)");
            $stmt->execute([$data['date'], $data['notes'] ?? '', $userId]);
            $entryId = $conn->lastInsertId();
            
            $stmt = $conn->prepare("INSERT INTO income_entry_lines (entry_id, method_id, amount) VALUES (?, ?, ?)");
            foreach ($data['lines'] as $line) {
                $stmt->execute([$entryId, $line['methodId'], $line['amount']]);
            }
            
            $conn->commit();
            sendResponse(['success' => true, 'id' => $entryId]);
        } catch (Exception $e) {
            $conn->rollBack();
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'PUT':
        $conn->beginTransaction();
        try {
            $stmt = $conn->prepare("UPDATE income_entries SET date=?, notes=? WHERE id=?");
            $stmt->execute([$data['date'], $data['notes'] ?? '', $data['id']]);
            
            $conn->prepare("DELETE FROM income_entry_lines WHERE entry_id=?")->execute([$data['id']]);
            
            $stmt = $conn->prepare("INSERT INTO income_entry_lines (entry_id, method_id, amount) VALUES (?, ?, ?)");
            foreach ($data['lines'] as $line) {
                $stmt->execute([$data['id'], $line['methodId'], $line['amount']]);
            }
            
            $conn->commit();
            sendResponse(['success' => true]);
        } catch (Exception $e) {
            $conn->rollBack();
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    case 'DELETE':
        try {
            $stmt = $conn->prepare("DELETE FROM income_entries WHERE id = ?");
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
