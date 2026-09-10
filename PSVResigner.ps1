class PSVResigner {
    hidden static [int] $SeedOffset = 8
    hidden static [int] $HashOffset = 28
    hidden static [int] $TypeOffset = 60
    hidden static [int] $HashSize = 20
    hidden static [string] $Magic = "00565350"
    hidden static [byte[]] $PS1Key = (0xAB, 0x5A, 0xBC, 0x9F, 0xC1, 0xF4, 0x9D, 0xE6, 0xA0, 0x51, 0xDB, 0xAE, 0xFA, 0x51, 0x88, 0x59)
    hidden static [byte[]] $PS2Key = (0xFA, 0x72, 0xCE, 0xEF, 0x59, 0xB4, 0xD2, 0x98, 0x9F, 0x11, 0x19, 0x13, 0x28, 0x7F, 0x51, 0xC7)
    hidden static [byte[]] $IV = (0xB3, 0x0F, 0xFE, 0xED, 0xB7, 0xDC, 0x5E, 0xB7, 0x13, 0x3D, 0xA6, 0x0D, 0x1B, 0x6B, 0x2C, 0xDC)

    hidden static [void] Xor([byte[]] $buf, [byte] $val, [int] $n) {
        for($i = 0; $i -lt $n; $i++) {
            $buf[$i] = $buf[$i] -bxor $val
        }
    }

    hidden static [void] Xor([byte[]] $buf, [int] $off, [byte[]] $val, [int] $n) {
        for($i = 0; $i -lt $n; $i++) {
            $buf[$off + $i] = $buf[$off + $i] -bxor $val[$i]
        }
    }

    hidden static [byte[]] InvokeAES([string] $mode, [byte[]] $key, [byte[]] $iv, [byte[]] $data, [bool] $dec) {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::None
        $aes.Key = $key

        if($mode -eq "ECB") {
            $aes.Mode = [System.Security.Cryptography.CipherMode]::ECB
        }
        elseif($mode -eq "CBC") {
            $aes.IV = $iv
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        }
        else {
            return $null
        }

        $tr = if($dec) {
            $aes.CreateDecryptor()
        }
        else {
            $aes.CreateEncryptor()
        }
        $res = $tr.TransformFinalBlock($data, 0, $data.Length)
        $tr.Dispose()
        $aes.Dispose()

        return $res
    }

    hidden static [byte[]] GetSHA1([byte[]] $data) {
        $sha1 = [System.Security.Cryptography.SHA1]::Create()
        $hash = $sha1.ComputeHash($data)
        $sha1.Dispose()
        return $hash
    }

    hidden static [byte[]] GetSignature([byte[]] $data, [int] $type) {
        $salt = [byte[]]::new(64)
        $buf = [byte[]]::new(20)

        $saltSeed = [byte[]]::new(20)
        [Array]::Copy($data, [PSVResigner]::SeedOffset, $saltSeed, 0, 20)

        if($type -eq 1) {
            $block = [byte[]]::new(16)
            [Array]::Copy($saltSeed, 0, $block, 0, 16)

            $dec = [PSVResigner]::InvokeAES("ECB", [PSVResigner]::PS1Key, $null, $block, $true)
            [Array]::Copy($dec, 0, $salt, 0, 16)

            $enc = [PSVResigner]::InvokeAES("ECB", [PSVResigner]::PS1Key, $null, $block, $false)
            [Array]::Copy($enc, 0, $salt, 16, 16)

            [PSVResigner]::Xor($salt, 0, [PSVResigner]::IV, 16)

            for($i = 0; $i -lt 20; $i++) {
                $buf[$i] = [byte] 0xFF
            }

            [Array]::Copy($saltSeed, 16, $buf, 0, 4)
            [PSVResigner]::Xor($salt, 16, $buf, 16)
        }
        elseif($type -eq 2) {
            $laidPaid = [byte[]] (0x10, 0x70, 0x00, 0x00, 0x02, 0x00, 0x00, 0x01, 0x10, 0x70, 0x00, 0x03, 0xFF, 0x00, 0x00, 0x01)
            [PSVResigner]::Xor($laidPaid, 0, [PSVResigner]::PS2Key, 16)

            [Array]::Copy($saltSeed, 0, $salt, 0, 20)
            $salt = [PSVResigner]::InvokeAES("CBC", $laidPaid, [PSVResigner]::IV, $salt, $true)
        }
        else {
            return $null
        }

        for($i = 20; $i -lt 64; $i++) {
            $salt[$i] = 0
        }

        [PSVResigner]::Xor($salt, 54, 64)

        $dataCopy = [byte[]]::new($data.Length)
        [Array]::Copy($data, 0, $dataCopy, 0, $data.Length)

        for($i = 0; $i -lt 20; $i++) {
            $dataCopy[[PSVResigner]::HashOffset + $i] = 0
        }

        $sha1Data = [byte[]]::new(64 + $dataCopy.Length)
        [Array]::Copy($salt, 0, $sha1Data, 0, 64)
        [Array]::Copy($dataCopy, 0, $sha1Data, 64, $dataCopy.Length)

        $buf = [PSVResigner]::GetSHA1($sha1Data)
        [PSVResigner]::Xor($salt, 106, 64)

        $sha1Data = [byte[]]::new(84)
        [Array]::Copy($salt, 0, $sha1Data, 0, 64)
        [Array]::Copy($buf, 0, $sha1Data, 64, 20)

        return [PSVResigner]::GetSHA1($sha1Data)
    }

    hidden static [string] GetType([int] $type) {
        if($type -eq 1) {
            return "PS1"
        }
        elseif($type -eq 2) {
            return "PS2"
        }
        return "Unknown"
    }

    static [void] ResignPSV([string] $path) {
        $data = [IO.File]::ReadAllBytes($path)
        $type = [int] $data[[PSVResigner]::TypeOffset]
        $sign = [PSVResigner]::GetSignature($data, $type)
        [Array]::Copy($sign, 0, $data, [PSVResigner]::HashOffset, 20)
        [IO.File]::WriteAllBytes($path, $data)
    }

    static [PSCustomObject] GetPSVInfo([string] $path) {
        $data = [IO.File]::ReadAllBytes($path)
        $type = [int] $data[[PSVResigner]::TypeOffset]
        $sign = [PSVResigner]::GetSignature($data, $type)

        $saveMagic = ($data[0..3] | ForEach-Object { "{0:X2}" -f $_ }) -join ""
        $saveType = [PSVResigner]::GetType($type)

        $start = [PSVResigner]::HashOffset;
        $end = $start + [PSVResigner]::HashSize - 1
        $saveSign = ($data[$start..$end] | ForEach-Object { "{0:X2}" -f $_ }) -join ""
        $calcSign = ($sign | ForEach-Object { "{0:X2}" -f $_ }) -join ""

        return [PSCustomObject] @{
            magic = $saveMagic
            validMagic = $saveMagic -eq [PSVResigner]::Magic
            type = $saveType
            sign = $saveSign
            validSign = $saveSign -eq $calcSign
        }
    }
}