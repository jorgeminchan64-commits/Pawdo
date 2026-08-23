param(
  [string]$ProjectRoot = (Resolve-Path "$PSScriptRoot\..")
)

Add-Type -AssemblyName System.Drawing

function Get-FrameFraction {
  param([int]$Value, [double[]]$Edges)
  for ($index = 0; $index -lt $Edges.Length - 1; $index++) {
    if ($Value -ge $Edges[$index] -and $Value -lt $Edges[$index + 1]) {
      return ($Value - $Edges[$index]) / ($Edges[$index + 1] - $Edges[$index])
    }
  }
  return 0.0
}

function New-LayerMasks {
  param(
    [string]$Source,
    [string]$Prefix,
    [double[]]$XEdges,
    [double[]]$YEdges,
    [ValidateSet('boy', 'girl')][string]$Style
  )

  $sourceBitmap = [System.Drawing.Bitmap]::new($Source)
  $hair = [System.Drawing.Bitmap]::new($sourceBitmap.Width, $sourceBitmap.Height)
  $skin = [System.Drawing.Bitmap]::new($sourceBitmap.Width, $sourceBitmap.Height)
  $outfit = [System.Drawing.Bitmap]::new($sourceBitmap.Width, $sourceBitmap.Height)
  $shoes = [System.Drawing.Bitmap]::new($sourceBitmap.Width, $sourceBitmap.Height)
  $transparent = [System.Drawing.Color]::FromArgb(0, 255, 255, 255)

  try {
    for ($y = 0; $y -lt $sourceBitmap.Height; $y++) {
      $frameY = Get-FrameFraction -Value $y -Edges $YEdges
      for ($x = 0; $x -lt $sourceBitmap.Width; $x++) {
        $pixel = $sourceBitmap.GetPixel($x, $y)
        if ($pixel.A -lt 16) {
          $hair.SetPixel($x, $y, $transparent)
          $skin.SetPixel($x, $y, $transparent)
          $outfit.SetPixel($x, $y, $transparent)
          $shoes.SetPixel($x, $y, $transparent)
          continue
        }

        $hue = $pixel.GetHue()
        $saturation = $pixel.GetSaturation()
        $brightness = $pixel.GetBrightness()
        # Keep soft luminance instead of a flat white mask so tinting preserves
        # the painted highlights and folds of every animation frame.
        $shade = [Math]::Clamp([int](140 + ($brightness * 115)), 140, 255)
        $alphaWhite = [System.Drawing.Color]::FromArgb($pixel.A, $shade, $shade, $shade)

        $isHair = $frameY -lt 0.48 -and $hue -ge 5 -and $hue -le 48 -and
          $saturation -gt 0.22 -and $brightness -lt 0.58
        $isSkin = $hue -ge 2 -and $hue -le 48 -and $saturation -gt 0.12 -and
          $saturation -lt 0.72 -and $brightness -gt 0.52 -and -not $isHair

        if ($Style -eq 'boy') {
          $isOutfit = $hue -ge 190 -and $hue -le 245 -and
            $saturation -gt 0.16 -and $brightness -gt 0.24
        } else {
          $isOutfit = (($hue -ge 330) -or ($hue -le 12)) -and
            $saturation -gt 0.25 -and $brightness -gt 0.28 -and
            $frameY -gt 0.20
        }
        $isShoes = $frameY -gt 0.76 -and $saturation -gt 0.12 -and
          $brightness -lt 0.82

        $hair.SetPixel($x, $y, $(if ($isHair) { $alphaWhite } else { $transparent }))
        $skin.SetPixel($x, $y, $(if ($isSkin) { $alphaWhite } else { $transparent }))
        $outfit.SetPixel($x, $y, $(if ($isOutfit -and -not $isShoes) { $alphaWhite } else { $transparent }))
        $shoes.SetPixel($x, $y, $(if ($isShoes) { $alphaWhite } else { $transparent }))
      }
    }

    $outputDirectory = Join-Path $ProjectRoot 'assets\images\avatars\layers'
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $hair.Save((Join-Path $outputDirectory "${Prefix}_hair.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $skin.Save((Join-Path $outputDirectory "${Prefix}_skin.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $outfit.Save((Join-Path $outputDirectory "${Prefix}_outfit.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $shoes.Save((Join-Path $outputDirectory "${Prefix}_shoes.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $sourceBitmap.Dispose()
    $hair.Dispose()
    $skin.Dispose()
    $outfit.Dispose()
    $shoes.Dispose()
  }
}

$avatarDirectory = Join-Path $ProjectRoot 'assets\images\avatars'
New-LayerMasks `
  -Source (Join-Path $avatarDirectory 'avatar_boy_pro_spritesheet.png') `
  -Prefix 'avatar_boy' `
  -XEdges @(0, 211, 412, 606, 836) `
  -YEdges @(0, 235, 455, 674, 875, 1079, 1287, 1507, 1710, 1881) `
  -Style 'boy'
New-LayerMasks `
  -Source (Join-Path $avatarDirectory 'avatar_girl_pro_spritesheet.png') `
  -Prefix 'avatar_girl' `
  -XEdges @(0, 235, 432, 628, 836) `
  -YEdges @(0, 233, 450, 668, 888, 1095, 1304, 1530, 1709, 1881) `
  -Style 'girl'

Write-Output 'Avatar layer masks generated.'
