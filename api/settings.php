<?php
// settings.php - Application settings management
require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$db = new Database();
$conn = $db->getConnection();
$data = getRequestData();

switch ($method) {
    case 'GET':
        $stmt = $conn->query("SELECT * FROM settings LIMIT 1");
        $settings = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($settings) {
            sendResponse([
                'companyName' => $settings['company_name'],
                'smtpSettings' => [
                    'host' => $settings['smtp_host'],
                    'port' => $settings['smtp_port'],
                    'user' => $settings['smtp_user'],
                    'password' => '***', // Don't send actual password
                    'secure' => (bool)$settings['smtp_secure'],
                    'fromName' => $settings['smtp_from_name'],
                    'fromEmail' => $settings['smtp_from_email']
                ]
            ]);
        } else {
            sendResponse([
                'companyName' => 'AdminLTE Finance',
                'smtpSettings' => [
                    'host' => '',
                    'port' => 587,
                    'user' => '',
                    'password' => '',
                    'secure' => true,
                    'fromName' => '',
                    'fromEmail' => ''
                ]
            ]);
        }
        break;
        
    case 'POST':
    case 'PUT':
        try {
            $stmt = $conn->prepare****_
