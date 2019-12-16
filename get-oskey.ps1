# 24 символа, использующиеся в ключах продукта Microsoft
$base24 = 'BCDFGHJKMPQRTVWXY2346789';
# длина ключа продукта в символах
$decodeStringLength = 24;
# длина ключа продукта в байтах
$decodeLength = 14;
# строка с расшифрованным ключом
$decodedKey = ' ';

#Извлекаем зашифрованный ключ из реестра и сохраняем его в массив

$digitalProductId = (Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').GetValue('DigitalProductId')[52..66]

#Проверяем наличие в ключе буквы ‘N’ (для Windows 8 и старше)

#Если третий бит младшего байта массива равен 1, то в номере присутствует буква ‘N’
$containsN = ($digitalProductId[$decodeLength] -shr 3) -bAnd 1;

#Для корректной расшифровки номера этот бит необходимо сбросить
$digitalProductId[$decodeLength] = $digitalProductId[$decodeLength] -band 0xF7;

<# Расшифровка ключа. Заключается в том, что полученное из реестра значение $digitalProductId переводится в систему счисления с основанием 24, затем каждая цифра заменяется на символ из $base24, индексом которого является эта цифра #>

for ($i = $decodeStringLength; $i -ge 0; $i--) {

# Переменная для хранения индекса текущего символа, перед началом вычисления обнуляем
$digitMapIndex = 0;

for ($j = $decodeLength; $j -ge 0; $j--) {

<# Размерность в байтах, поэтому исходное основание 256. Умножаем на него остаток от предыдущей итерации и добавляем цифру из следующего разряда #>
$digitMapIndex = ($digitMapIndex -shl 8) -bXor $digitalProductId[$j];

<# Делим $digitMapIndex на количество символов в $base24. Частное попадает в $digitalProductId[$j],
а остаток от деления в $digitMapIndex #>
$digitalProductId[$j] = [System.Math]::DivRem($digitMapIndex, $base24.Length, [ref]$digitMapIndex);

}

# Находим в $base24 символ с полученным индексом и добавляем его в $decodedKey
$decodedKey = $decodedKey.Insert(0, $base24[$digitMapIndex]);

}

<# Если в ключе присутвует символ ′N′, то добавляем его. Для этого находим в расшифрованной строке первый символ и запоминаем его индекс в $base24. Затем удаляем первый символ, а в оставшуюся строку вставляем ′N′ в позицию с номером индекса удалённого символа #>

if ($containsN -eq 1) {

$index = $base24.IndexOf($decodedKey[0]);
$decodedKey = $decodedKey.Substring(1).Insert($index, 'N');

}

# Вставляем тире через каждые пять символов

for ($n = 20; $n -ge 5; $n -= 5){$decodedKey = $decodedKey.Insert($n, '-')}

# Формируем вывод, добавляем в него дополнительную информацию об операционной системе

$Target = [System.Net.Dns]::GetHostName();
$win32os = Get-WmiObject -Class 'Win32_OperatingSystem' -ComputerName $target;
$product = New-Object -TypeName System.Object;

$product | Add-Member -MemberType 'NoteProperty' -Name 'Computer' -Value $target
$product | Add-Member -MemberType 'NoteProperty' -Name 'Caption' -Value $win32os.Caption
$product | Add-Member -MemberType 'NoteProperty' -Name 'OSArch' -Value $win32os.OSArchitecture
$product | Add-Member -MemberType 'NoteProperty' -Name 'BuildNumber' -Value $win32os.BuildNumber
$product | Add-Member -MemberType 'NoteProperty' -Name 'ProductID' -Value $win32os.SerialNumber
$product | Add-Member -MemberType 'NoteProperty' -Name 'ProductKey' -Value $decodedKey

Write-Output $product;