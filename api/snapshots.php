<?php
// snapshots.php - Account snapshots management
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($method) {
    case 'GET':
        $stmt = $conn->query("
            SELECT 
                s.id,
                s.month,
                s.is_locked as isLocked,
                GROUP_CONCAT(CONCAT(sb.account_id, ':', sb.balance) SEPARATOR ';') as balances
            FROM account_snapshots s
            LEFT JOIN snapshot_balances sb ON s.id = sb.snapshot_id
            GROUP BY s.id
            ORDER BY s.month DESC
        ");
        
        $snapshots = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $balances = [];
            if ($row['balances']) {
                foreach (explode(';', $row['balances']) as $balance) {
                    list($accountId, $amount) = explode(':', $balance);
                    $balances[] = ['accountId' => (int)$accountId, 'balance' => (float)$amount];
                }
            }
            $row['balances'] = $balances;
            $snapshots[] = $row;
        }
        sendResponse($snapshots);
        break;
        
    case 'POST':
        $conn->beginTransaction();
        try {
            // Check if snapshot for this month exists
            $stmt = $conn->prepare("SELECT id FROM account_snapshots WHERE month = ?");
            $stmt->execute([$data['month']]);
            $existing = $stmt->fetchColumn();
            
            if ($existing) {
                // Delete existing balances
                $conn->prepare("DELETE FROM snapshot_balances WHERE snapshot_id = ?")->execute([$existing]);
                $snapshotId = $existing;
            } else {
                // Create new snapshot
                $stmt = $conn->prepare("INSERT INTO account_snapshots (month, is_locked) VALUES (?, ?)");
                $stmt->execute([$data['month'], $data['isLocked'] ?? true]);
                $snapshotId = $conn->lastInsertId();
            }
            
            // Insert balances
            $stmt = $conn->prepare("INSERT INTO snapshot_balances (snapshot_id, account_id, balance) VALUES (?, ?, ?)");
            foreach ($data['balances'] as $balance) {
                $stmt->execute([$snapshotId, $balance['accountId'], $balance['balance']]);
            }
            
            $conn->commit();
            sendResponse(['success' => true, 'id' => $snapshotId]);
        } catch (Exception $e) {
            $conn->rollBack();
            sendResponse(['error' => $e->getMessage()], 500);
        }
        break;
        
    default:
        sendResponse(['error' => 'Method not allowed'], 405);
}
?>
