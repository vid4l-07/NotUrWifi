<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Capturar los datos del formulario
    $nombre = $_POST['nombre'];
    $mensaje = $_POST['mensaje'];

    // Crear la línea de texto que se va a guardar
    $linea = "Nombre: $nombre | Mensaje: $mensaje\n";

    // Guardar en el archivo 'datos.txt'
    $archivo = 'datos.txt';
    file_put_contents($archivo, $linea, FILE_APPEND);

    echo "¡Datos guardados correctamente!";
} else {
    echo "Método no permitido.";
}
?>
