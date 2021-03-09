# The Smurfs Cipher

## Description

We were given a website that accepted a file upload.
As well, we were told that a file named `cipher` contains the text `8b6f40f3` and had access to the following PHP code:

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

When I learned PHP, I was taught that one should never use a simple `==` comparison when dealing with passwords.
Timing attacks are one potential risk, but in this case, pulling one off would likely be too difficult\* for this competition.

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
Consequently, I converted `4062869629976844658` into hex to get `38623667077E1972`.
I then used a hex editor to convert `38623667077E1972` to the ASCII characters `8b6g~r` (two of which are non-printable characters).

Storing this string in a file named `key` and uploading it to the server got us the flag `magpie{l0053_c0mp4r150n_l34d5_t0_tr0ub13}`.

## \*Additional notes on timing attacks

Timing attacks take advantage of how long the code takes to execute given different inputs.
String comparison using `==` (or even `===`) would be vulnerable to a timing attack.

The comparison of interest is `$to_check == $password`.
For simplicity, let's assume we have control over `$to_check` and `$password` is unknown.
Let's also assume delay due to networking is constant.

The `==` operator is internally implemented in PHP in a fashion similar to the following pseudocode when applied to strings:

```python
if type(to_check) is not type(password):
  # Perform type juggling. This is what I exploited.
if len(to_check) is not len(password):
  # Interesting, the code returns fastest when the lengths differ.
  return False
for i in range(len(to_check)):
  if to_check[i] is not password[i]:
    # It returns next fastest when the first characters do not match.
    return False
# Equality is the slowest.
return True
```

On a scale of nanoseconds, these differences in times can divulge information about what the password is.
The easiest information to divulge via a timing attack is the length of the password.

Suppose I write some code to send one million values of `to_check` that are of length 1.
Then, I compute the average amount of time a request takes.
I repeat this process for values of `to_check` that are of lengths 2, 3, 4, 5, 6, 7, and 8.
After sending my 8 million requests, I will have 8 averages.
One of these averages should be noticeably larger than the others.
Suppose our average for values of length 8 is the highest.
From this, I can conclude with high probability that the password is in fact of length 8.

Once we determine the password length, we can start to determine the contents of the password.
Let's assume this password is made up of 8-bit characters only.
We can try all 2^8 = 256 possible characters as the first character of `to_check`.
That is, `\x00\x00\x00\x00\x00\x00\x00\x00`, `\x01\x00\x00\x00\x00\x00\x00\x00`, `\x02\x00\x00\x00\x00\x00\x00\x00`, ..., `\xFF\x00\x00\x00\x00\x00\x00\x00`.
We may have to send all of these 256 values one million times each and compute an average.
This is where this attack gets infeasible, as I was not interested in launching what would've been seen as a DOS attack against our gracious CTF hosts.

However, suppose I was evil and did want to give the magpieCTF servers a beating.
By figuring out which average is highest, I've now discovered the first character of the password.
I can repeat this process for characters 2, 3, 4, 5, 6, 7, and 8.
You might think this is crazy; I'm guessing 8 million passwords to get the length and 256 million passwords per character.
However, it's substantially easier to crack a password this way than by performing a brute force attack.

Some math:
A password of length 8 takes up to `(2^8)^8 = 18446744073709551616` guesses to crack.
The timing attack I propose takes `8(1000000) + 256(1000000) * 8 = 2056000000` guesses.

Why didn't I try this attack?
My assumption that delay due to networking is constant is completely false.
Network delay would seriously mess up my ability to pull off this attack, as timing attacks require nanosecond resolution and packets can take hundreds of milliseconds to travel.
I could compensate for this by increasing one million to one billion guesses per average.
However, I wanted to be a reasonable competitor and chose to exploit type juggling instead.
