unit Calc.Xaml;

{
  All XAML of the calculator (Windows 10 style, dark theme).
  Needs Delphi 12+ (multi-line string literals). The file is pure ASCII: special
  glyphs are written as XML character references (&#x00F7; = division sign, ...).

  Names used by Calc.View (x:Name):
    main   : DisplayText ExprText Host KeypadGrid BtnHistory
             BtnMC BtnMR BtnMPlus BtnMMinus BtnMS BtnMList
             BtnPercent BtnCE BtnC BtnBack BtnRecip BtnSqr BtnSqrt BtnDiv
             Btn0..Btn9 BtnMul BtnSub BtnAdd BtnNeg BtnDot BtnEq
    panel  : PanelGrid PanelTitle BtnSwitch BtnClearList ListHost
    list   : I0, I1, ... (created at run time)
}

interface

const
  cNs =
    'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" ' +
    'xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"';

  // Shared key styles. Hover / pressed = white overlay, disabled = dimmed content.
  cCalcStyles = '''
    <Style x:Key="KeyBase" TargetType="Button">
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="Background" Value="#3B3B3B"/>
      <Setter Property="FontSize" Value="20"/>
      <Setter Property="Margin" Value="1"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="HorizontalAlignment" Value="Stretch"/>
      <Setter Property="VerticalAlignment" Value="Stretch"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Chrome" Background="{TemplateBinding Background}" CornerRadius="4">
              <Grid>
                <Border x:Name="Overlay" Background="#FFFFFF" Opacity="0" CornerRadius="4" IsHitTestVisible="False"/>
                <ContentPresenter x:Name="Presenter"
                                  Content="{TemplateBinding Content}"
                                  Padding="{TemplateBinding Padding}"
                                  Foreground="{TemplateBinding Foreground}"
                                  FontSize="{TemplateBinding FontSize}"
                                  FontFamily="{TemplateBinding FontFamily}"
                                  FontWeight="{TemplateBinding FontWeight}"
                                  HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                  VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
              </Grid>
              <VisualStateManager.VisualStateGroups>
                <VisualStateGroup x:Name="CommonStates">
                  <VisualState x:Name="Normal"/>
                  <VisualState x:Name="PointerOver">
                    <VisualState.Setters>
                      <Setter Target="Overlay.Opacity" Value="0.10"/>
                    </VisualState.Setters>
                  </VisualState>
                  <VisualState x:Name="Pressed">
                    <VisualState.Setters>
                      <Setter Target="Overlay.Opacity" Value="0.20"/>
                    </VisualState.Setters>
                  </VisualState>
                  <VisualState x:Name="Disabled">
                    <VisualState.Setters>
                      <Setter Target="Presenter.Opacity" Value="0.35"/>
                    </VisualState.Setters>
                  </VisualState>
                </VisualStateGroup>
              </VisualStateManager.VisualStateGroups>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="NumKey" TargetType="Button" BasedOn="{StaticResource KeyBase}">
      <Setter Property="Background" Value="#3B3B3B"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="OpKey" TargetType="Button" BasedOn="{StaticResource KeyBase}">
      <Setter Property="Background" Value="#323232"/>
      <Setter Property="FontSize" Value="18"/>
    </Style>
    <Style x:Key="OpIconKey" TargetType="Button" BasedOn="{StaticResource OpKey}">
      <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="16"/>
    </Style>
    <Style x:Key="EqKey" TargetType="Button" BasedOn="{StaticResource KeyBase}">
      <Setter Property="Background" Value="#4CC2FF"/>
      <Setter Property="Foreground" Value="#000000"/>
      <Setter Property="FontSize" Value="24"/>
    </Style>
    <Style x:Key="MemKey" TargetType="Button" BasedOn="{StaticResource KeyBase}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>
    <Style x:Key="IconKey" TargetType="Button" BasedOn="{StaticResource KeyBase}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="Margin" Value="0"/>
    </Style>
    <Style x:Key="TextKey" TargetType="Button" BasedOn="{StaticResource KeyBase}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Padding" Value="12,6,12,6"/>
      <Setter Property="Margin" Value="0"/>
    </Style>
    <Style x:Key="ItemKey" TargetType="Button" BasedOn="{StaticResource KeyBase}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Padding" Value="12,6,12,6"/>
      <Setter Property="Margin" Value="0,0,0,2"/>
      <Setter Property="VerticalAlignment" Value="Top"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    </Style>
    ''';

  cMainBody = '''
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="76"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
    </Grid.RowDefinitions>

    <Grid Grid.Row="0" Margin="14,8,6,0" Height="40">
      <TextBlock Text="Standard" FontSize="20" FontWeight="SemiBold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
      <Button x:Name="BtnHistory" Style="{StaticResource IconKey}" Content="&#xE81C;" Width="40" Height="40"
              HorizontalAlignment="Right" AutomationProperties.Name="History"/>
    </Grid>

    <Viewbox Grid.Row="1" Height="22" HorizontalAlignment="Right" Stretch="Uniform" StretchDirection="DownOnly" Margin="14,0,14,0">
      <TextBlock x:Name="ExprText" Text="" FontSize="14" Foreground="#C0C0C0"/>
    </Viewbox>

    <Viewbox Grid.Row="2" HorizontalAlignment="Right" VerticalAlignment="Bottom" Stretch="Uniform" StretchDirection="DownOnly" Margin="14,0,14,6">
      <TextBlock x:Name="DisplayText" Text="0" FontSize="54" FontFamily="Segoe UI" FontWeight="SemiLight" Foreground="#FFFFFF"/>
    </Viewbox>

    <Grid Grid.Row="3" Margin="6,0,6,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Button x:Name="BtnMC" Grid.Column="0" Style="{StaticResource MemKey}" Content="MC" Height="32" AutomationProperties.Name="Memory clear"/>
      <Button x:Name="BtnMR" Grid.Column="1" Style="{StaticResource MemKey}" Content="MR" Height="32" AutomationProperties.Name="Memory recall"/>
      <Button x:Name="BtnMPlus" Grid.Column="2" Style="{StaticResource MemKey}" Content="M+" Height="32" AutomationProperties.Name="Memory add"/>
      <Button x:Name="BtnMMinus" Grid.Column="3" Style="{StaticResource MemKey}" Content="M&#x2212;" Height="32" AutomationProperties.Name="Memory subtract"/>
      <Button x:Name="BtnMS" Grid.Column="4" Style="{StaticResource MemKey}" Content="MS" Height="32" AutomationProperties.Name="Memory store"/>
      <Button x:Name="BtnMList" Grid.Column="5" Style="{StaticResource MemKey}" Content="M&#x25BE;" Height="32" AutomationProperties.Name="Memory list"/>
    </Grid>

    <ContentControl x:Name="Host" Grid.Row="4" IsTabStop="False"
                    HorizontalAlignment="Stretch" VerticalAlignment="Stretch"
                    HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch">
      <Grid x:Name="KeypadGrid" Margin="2">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
          <RowDefinition Height="*"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Button x:Name="BtnPercent" Grid.Row="0" Grid.Column="0" Style="{StaticResource OpKey}" Content="%" AutomationProperties.Name="Percent"/>
        <Button x:Name="BtnCE" Grid.Row="0" Grid.Column="1" Style="{StaticResource OpKey}" Content="CE" AutomationProperties.Name="Clear entry"/>
        <Button x:Name="BtnC" Grid.Row="0" Grid.Column="2" Style="{StaticResource OpKey}" Content="C" AutomationProperties.Name="Clear"/>
        <Button x:Name="BtnBack" Grid.Row="0" Grid.Column="3" Style="{StaticResource OpIconKey}" Content="&#xE94F;" AutomationProperties.Name="Backspace"/>

        <Button x:Name="BtnRecip" Grid.Row="1" Grid.Column="0" Style="{StaticResource OpKey}" Content="1/x" AutomationProperties.Name="Reciprocal"/>
        <Button x:Name="BtnSqr" Grid.Row="1" Grid.Column="1" Style="{StaticResource OpKey}" Content="x&#x00B2;" AutomationProperties.Name="Square"/>
        <Button x:Name="BtnSqrt" Grid.Row="1" Grid.Column="2" Style="{StaticResource OpKey}" Content="&#x221A;" AutomationProperties.Name="Square root"/>
        <Button x:Name="BtnDiv" Grid.Row="1" Grid.Column="3" Style="{StaticResource OpKey}" Content="&#x00F7;" AutomationProperties.Name="Divide by"/>

        <Button x:Name="Btn7" Grid.Row="2" Grid.Column="0" Style="{StaticResource NumKey}" Content="7" AutomationProperties.Name="Seven"/>
        <Button x:Name="Btn8" Grid.Row="2" Grid.Column="1" Style="{StaticResource NumKey}" Content="8" AutomationProperties.Name="Eight"/>
        <Button x:Name="Btn9" Grid.Row="2" Grid.Column="2" Style="{StaticResource NumKey}" Content="9" AutomationProperties.Name="Nine"/>
        <Button x:Name="BtnMul" Grid.Row="2" Grid.Column="3" Style="{StaticResource OpKey}" Content="&#x00D7;" AutomationProperties.Name="Multiply by"/>

        <Button x:Name="Btn4" Grid.Row="3" Grid.Column="0" Style="{StaticResource NumKey}" Content="4" AutomationProperties.Name="Four"/>
        <Button x:Name="Btn5" Grid.Row="3" Grid.Column="1" Style="{StaticResource NumKey}" Content="5" AutomationProperties.Name="Five"/>
        <Button x:Name="Btn6" Grid.Row="3" Grid.Column="2" Style="{StaticResource NumKey}" Content="6" AutomationProperties.Name="Six"/>
        <Button x:Name="BtnSub" Grid.Row="3" Grid.Column="3" Style="{StaticResource OpKey}" Content="&#x2212;" AutomationProperties.Name="Minus"/>

        <Button x:Name="Btn1" Grid.Row="4" Grid.Column="0" Style="{StaticResource NumKey}" Content="1" AutomationProperties.Name="One"/>
        <Button x:Name="Btn2" Grid.Row="4" Grid.Column="1" Style="{StaticResource NumKey}" Content="2" AutomationProperties.Name="Two"/>
        <Button x:Name="Btn3" Grid.Row="4" Grid.Column="2" Style="{StaticResource NumKey}" Content="3" AutomationProperties.Name="Three"/>
        <Button x:Name="BtnAdd" Grid.Row="4" Grid.Column="3" Style="{StaticResource OpKey}" Content="+" AutomationProperties.Name="Plus"/>

        <Button x:Name="BtnNeg" Grid.Row="5" Grid.Column="0" Style="{StaticResource NumKey}" Content="&#x00B1;" AutomationProperties.Name="Positive negative"/>
        <Button x:Name="Btn0" Grid.Row="5" Grid.Column="1" Style="{StaticResource NumKey}" Content="0" AutomationProperties.Name="Zero"/>
        <Button x:Name="BtnDot" Grid.Row="5" Grid.Column="2" Style="{StaticResource NumKey}" Content="." AutomationProperties.Name="Decimal separator"/>
        <Button x:Name="BtnEq" Grid.Row="5" Grid.Column="3" Style="{StaticResource EqKey}" Content="=" AutomationProperties.Name="Equals"/>
      </Grid>
    </ContentControl>
    ''';

  // Root of the calculator window content.
  cMainXaml =
    '<Grid ' + cNs + ' x:Name="Root" RequestedTheme="Dark" Background="#202020">' +
    '<Grid.Resources>' + cCalcStyles + '</Grid.Resources>' +
    cMainBody +
    '</Grid>';

  cPanelBody = '''
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
    </Grid.RowDefinitions>
    <Grid Grid.Row="0" Margin="14,4,6,4">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock x:Name="PanelTitle" Text="History" FontSize="20" FontWeight="SemiBold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
      <Button x:Name="BtnSwitch" Grid.Column="1" Style="{StaticResource TextKey}" Content="Memory" VerticalAlignment="Center"
              AutomationProperties.Name="Switch list"/>
      <Button x:Name="BtnClearList" Grid.Column="2" Style="{StaticResource IconKey}" Content="&#xE74D;" Width="40" Height="40"
              AutomationProperties.Name="Clear list"/>
    </Grid>
    <ScrollViewer x:Name="ListHost" Grid.Row="1" IsTabStop="False" Padding="6,0,6,6"
                  VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"/>
    ''';

  // History / memory view that is swapped into the Host instead of the keypad.
  cPanelXaml =
    '<Grid ' + cNs + ' x:Name="PanelGrid">' +
    '<Grid.Resources>' + cCalcStyles + '</Grid.Resources>' +
    cPanelBody +
    '</Grid>';

  // Run-time list: cListHead + items (Buttons named I0, I1, ...) + cListTail
  cListHead =
    '<StackPanel ' + cNs + '><StackPanel.Resources>' + cCalcStyles + '</StackPanel.Resources>';
  cListTail = '</StackPanel>';

// Escapes text for use inside an XML attribute / element.
function XmlEscape(const S: string): string;

implementation

uses
  System.SysUtils;

function XmlEscape(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

end.
