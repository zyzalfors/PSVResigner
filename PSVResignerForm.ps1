class DarkToolStripRenderer : System.Windows.Forms.ToolStripProfessionalRenderer {

    DarkToolStripRenderer() : base([System.Windows.Forms.ProfessionalColorTable]::new()) {}

    [void] OnRenderToolStripBorder([System.Windows.Forms.ToolStripRenderEventArgs] $e) {}

    [void] OnRenderButtonBackground([System.Windows.Forms.ToolStripItemRenderEventArgs] $e) {
        if($e.Item.Selected) {
            $color = [System.Drawing.Color]::FromArgb(55, 55, 55)
            $brush = [System.Drawing.SolidBrush]::new($color)
            $e.Graphics.FillRectangle($brush, $e.Item.ContentRectangle)
            $brush.Dispose()
        }
    }
}

class PSVResignerForm : System.Windows.Forms.Form {
    hidden static [string] $Title = "PSV Resigner"
    hidden [string] $PSVPath
    hidden [System.Windows.Forms.Label] $PSVInfo

    PSVResignerForm([string] $path, [bool] $res) {
        $this.Text = [PSVResignerForm]::Title
        $this.Size = [System.Drawing.Size]::new(390, 140)
        $this.StartPosition = "CenterScreen"
        $this.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
        $this.MaximizeBox = $false
        $this.MinimizeBox = $true
        $this.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $this.ForeColor = [System.Drawing.Color]::Gainsboro

        $toolbar = [System.Windows.Forms.ToolStrip]::new()
        $toolbar.Dock = [System.Windows.Forms.DockStyle]::Top
        $toolbar.Renderer = [DarkToolStripRenderer]::new()
        $toolbar.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $toolbar.ForeColor = [System.Drawing.Color]::Gainsboro
        $toolbar.GripStyle = [System.Windows.Forms.ToolStripGripStyle]::Hidden

        $open = [System.Windows.Forms.ToolStripButton]::new("Open")
        $resign = [System.Windows.Forms.ToolStripButton]::new("Resign")

        $open.Add_Click({
            param($sender)

            $sender.GetCurrentParent().FindForm().OpenPSV()
        })

        $resign.Add_Click({
            param($sender)

            $sender.GetCurrentParent().FindForm().ResignPSV()
        })

        [void] $toolbar.Items.Add($open)
        [void] $toolbar.Items.Add($resign)
        [void] $this.Controls.Add($toolbar)

        $this.PSVInfo = [System.Windows.Forms.Label]::new()
        $this.PSVInfo.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $this.PSVInfo.Location = [System.Drawing.Point]::new(5, 30)
        $this.PSVInfo.Size = [System.Drawing.Size]::new(390, 70)
        $this.Controls.Add($this.PSVInfo)

        if([System.IO.File]::Exists($path)) {
            $this.PSVPath = $path

            if($res) {
                $this.ResignPSV()
            }
            else {
                $this.PrintPSV()
            }
        }
    }

    hidden [void] OpenPSV() {
        $dialog = [System.Windows.Forms.OpenFileDialog]::new()
        $dialog.Title = "Open PSV"
        $dialog.Filter = "PSV files (*.psv)|*.psv"
        $dialog.Multiselect = $false

        if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $this.PSVPath = $dialog.FileName
            $this.PrintPSV()
        }

        $dialog.Dispose()
    }

    hidden [void] PrintPSV() {
        $info = [PSVResigner]::GetPSVInfo($this.PSVPath)
        $sb = [System.Text.StringBuilder]::new()

        [void] $sb.AppendLine("Save: $([IO.Path]::GetFileName($this.PSVPath))")

        if($info.validMagic) {
            [void] $sb.AppendLine("Magic: $($info.magic)")
        }
        else {
            [void] $sb.AppendLine("Magic: $($info.magic) (invalid)")
        }

        [void] $sb.AppendLine("Type: $($info.type)")

        if($info.validSign) {
            [void] $sb.Append("Signature: $($info.sign)")
        }
        else {
            [void] $sb.Append("Signature: $($info.sign) (invalid)")
        }

        $this.PSVInfo.Text = $sb.ToString()
    }

    hidden [void] ResignPSV() {
        if([string]::IsNullOrWhiteSpace($this.PSVPath)) {
            return
        }

        if(-not [System.IO.File]::Exists($this.PSVPath)) {
            [System.Windows.Forms.MessageBox]::Show("Save not found", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        [PSVResigner]::ResignPSV($this.PSVPath)
        [System.Windows.Forms.MessageBox]::Show("Save resigned", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $this.PrintPSV()
    }
}