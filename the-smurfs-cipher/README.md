# The Smurfs Cipher

## Description

We were given a website that accepted a file upload. As well, we were told that a file named `cipher` contains the text `8b6f40f3` and had access to the following PHP code:

```php
<?php

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  if (isset($_FILES["key"])) {
    if ($_FILES["key"]["size"] !== 8) {
      echo "Sorry, your key is the wrong size!";
      return;
    }

    $flag = file_get_contents("/flag.txt");
    $password = file_get_contents("/password.txt");

    $cipher_bytes = read_file_to_bytes("cipher");
    $key_bytes = read_file_to_bytes($_FILES["key"]["tmp_name"]);

    $to_check = ($cipher_bytes + hexdec("d34db33f")) ^ $key_bytes;

    if ($to_check == $password) {
      echo $flag;
    } else {
      echo "Sorry, your key is incorrect!";
    }
  }
} else {
  echo show_source('decrypt.php', True);
}

// Cipher and key are read in as big-endian
function read_file_to_bytes($filename) {
  $file = fopen($filename, "rb");
  $content = fread($file, filesize($filename));
  $bytes = unpack("J", $content);

  return $bytes[1];
}

?>
```

## Solution

When I learned PHP, I was taught that one should never use a simple `==` comparison when dealing with password.
Timing attacks are one potential risk, but in this case, pulling one off would likely be too time consuming.

Similar to JavaScript, I recalled that the `==` operator in PHP performs what is known as type juggling.
Type juggling is essentially changing the type of a variable being compared so that the comparison makes logical sense.
For example, `0 == "password"` does not make much sense, so PHP would implicitly convert the string `"password"` to an integer.
Since `"password"` has no digits in the string, it ends up being converted into the integer `0`.
The comparison becomes `0 == 0`, which evaluates to `true`.
I suspected that this would be how we get the code above to echo the flag we wanted.

My goal became setting the variable `$to_check` to the integer zero.
We only had control over the file uploaded, so the contents of this file were my key to the kingdom.
One restriction was that this key had to be 8 bytes or the function would return early.
Another restriction is that `$key_bytes` is only used in one place: `$to_check = ($cipher_bytes + hexdec("d34db33f")) ^ $key_bytes;`
The `^` symbol is used to exclusive or (XOR) two values together, and one property of XOR is that any number XORed with itself equals zero.
Thus, I wanted `$cipher_bytes + hexdec("d34db33f")` to equal `$key_bytes`.

Another noteworthy observation is that the `read_file_to_bytes` function is called to read in the cipher and the key.
To help me determine what it was doing, I copied the PHP code locally and modified it to echo `$cipher_bytes` and `$cipher_bytes + hexdec("d34db33f")`.
The output was:

```
$cipher_bytes = 4062869626431759923
$cipher_bytes + hexdec("d34db33f") = 4062869629976844658
```

After some experimentation, I discovered that `4062869626431759923` in hex is `3862366634306633`.
Of note is that `3862366634306633` is the hex representation of the ASCII characters `8b6f40f3`, which is the cipher we were given.
Consequently, I converted `4062869629976844658` into hex to get `38623667077E1972`. I then used a hex editor to convert `38623667077E1972` to the ASCII characters `8b6g~r` (two of which are non-printable characters).

Storing this string in a file named `key` and uploading it to the server got us the flag `magpie{l0053_c0mp4r150n_l34d5_t0_tr0ub13}`.
