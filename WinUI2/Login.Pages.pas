unit Login.Pages;

{
  The three glass pages (login / register / reset password) as UWP XAML.

  Why custom templates: the inbox controls of Windows 10 have square corners and their default
  templates ignore Control.CornerRadius (only Windows 11 templates honour it). To get the same
  rounded glass look on a clean Windows 10 PC, TextBox / PasswordBox / Button get small
  ControlTemplates (cGlassResources). They are keyed styles, never implicit ones, so they cannot
  leak into the Button inside PasswordBox's own template.

  Markers replaced by PageXaml:
    %RES%  the shared glass styles
    %LUM%  AcrylicBrush.TintLuminosityOpacity (property element, Windows 10 1903+).
           PageXaml(..., False) removes it (Login.View retries without it if the parser refuses).
  Acrylic uses BackgroundSource="Backdrop" (in-app): HostBackdrop does not work inside XAML Islands.
}

interface

const
  cGlassResources = '''
<Style x:Key="GlassTextBox" TargetType="TextBox">
  <Setter Property="Background" Value="#26FFFFFF"/>
  <Setter Property="BorderBrush" Value="#55FFFFFF"/>
  <Setter Property="Foreground" Value="White"/>
  <Setter Property="FontSize" Value="15"/>
  <Setter Property="MinHeight" Value="42"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="TextBox">
        <Grid>
          <VisualStateManager.VisualStateGroups>
            <VisualStateGroup x:Name="CommonStates">
              <VisualState x:Name="Normal"/>
              <VisualState x:Name="PointerOver">
                <VisualState.Setters><Setter Target="Root.BorderBrush" Value="#99FFFFFF"/></VisualState.Setters>
              </VisualState>
              <VisualState x:Name="Focused">
                <VisualState.Setters><Setter Target="Root.BorderBrush" Value="#EEFFFFFF"/></VisualState.Setters>
              </VisualState>
              <VisualState x:Name="Disabled">
                <VisualState.Setters><Setter Target="Root.Opacity" Value="0.5"/></VisualState.Setters>
              </VisualState>
            </VisualStateGroup>
          </VisualStateManager.VisualStateGroups>
          <Border x:Name="Root" CornerRadius="10" BorderThickness="1"
                  Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"/>
          <ScrollViewer x:Name="ContentElement" Margin="12,0" VerticalAlignment="Center"
                        HorizontalScrollMode="Disabled" HorizontalScrollBarVisibility="Hidden"
                        VerticalScrollMode="Disabled" VerticalScrollBarVisibility="Hidden"
                        IsTabStop="False" ZoomMode="Disabled"/>
          <ContentControl x:Name="PlaceholderTextContentPresenter" Margin="12,0" VerticalAlignment="Center"
                          Foreground="#99FFFFFF" IsHitTestVisible="False" IsTabStop="False"
                          Content="{TemplateBinding PlaceholderText}"/>
        </Grid>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="GlassPasswordBox" TargetType="PasswordBox">
  <Setter Property="Background" Value="#26FFFFFF"/>
  <Setter Property="BorderBrush" Value="#55FFFFFF"/>
  <Setter Property="Foreground" Value="White"/>
  <Setter Property="FontSize" Value="15"/>
  <Setter Property="MinHeight" Value="42"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="PasswordBox">
        <Grid>
          <VisualStateManager.VisualStateGroups>
            <VisualStateGroup x:Name="CommonStates">
              <VisualState x:Name="Normal"/>
              <VisualState x:Name="PointerOver">
                <VisualState.Setters><Setter Target="Root.BorderBrush" Value="#99FFFFFF"/></VisualState.Setters>
              </VisualState>
              <VisualState x:Name="Focused">
                <VisualState.Setters><Setter Target="Root.BorderBrush" Value="#EEFFFFFF"/></VisualState.Setters>
              </VisualState>
              <VisualState x:Name="Disabled">
                <VisualState.Setters><Setter Target="Root.Opacity" Value="0.5"/></VisualState.Setters>
              </VisualState>
            </VisualStateGroup>
            <VisualStateGroup x:Name="ButtonStates">
              <VisualState x:Name="ButtonVisible">
                <VisualState.Setters><Setter Target="RevealButton.Visibility" Value="Visible"/></VisualState.Setters>
              </VisualState>
              <VisualState x:Name="ButtonCollapsed"/>
            </VisualStateGroup>
          </VisualStateManager.VisualStateGroups>
          <Border x:Name="Root" CornerRadius="10" BorderThickness="1"
                  Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ScrollViewer x:Name="ContentElement" Margin="12,0" VerticalAlignment="Center"
                          HorizontalScrollMode="Disabled" HorizontalScrollBarVisibility="Hidden"
                          VerticalScrollMode="Disabled" VerticalScrollBarVisibility="Hidden"
                          IsTabStop="False" ZoomMode="Disabled"/>
            <ContentControl x:Name="PlaceholderTextContentPresenter" Margin="12,0" VerticalAlignment="Center"
                            Foreground="#99FFFFFF" IsHitTestVisible="False" IsTabStop="False"
                            Content="{TemplateBinding PlaceholderText}"/>
            <Button x:Name="RevealButton" Grid.Column="1" Visibility="Collapsed" IsTabStop="False"
                    Width="40" VerticalAlignment="Stretch" Padding="0" BorderThickness="0"
                    Background="Transparent" Foreground="#CCFFFFFF"
                    FontFamily="Segoe MDL2 Assets" FontSize="14" Content="&#xE052;"/>
          </Grid>
        </Grid>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="GlassButtonBase" TargetType="Button">
  <Setter Property="Background" Value="Transparent"/>
  <Setter Property="Foreground" Value="White"/>
  <Setter Property="BorderBrush" Value="#66FFFFFF"/>
  <Setter Property="BorderThickness" Value="1"/>
  <Setter Property="Padding" Value="12,6"/>
  <Setter Property="HorizontalAlignment" Value="Stretch"/>
  <Setter Property="UseSystemFocusVisuals" Value="True"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Grid>
          <VisualStateManager.VisualStateGroups>
            <VisualStateGroup x:Name="CommonStates">
              <VisualState x:Name="Normal"/>
              <VisualState x:Name="PointerOver">
                <VisualState.Setters><Setter Target="Root.Opacity" Value="0.85"/></VisualState.Setters>
              </VisualState>
              <VisualState x:Name="Pressed">
                <VisualState.Setters><Setter Target="Root.Opacity" Value="0.65"/></VisualState.Setters>
              </VisualState>
              <VisualState x:Name="Disabled">
                <VisualState.Setters><Setter Target="Root.Opacity" Value="0.4"/></VisualState.Setters>
              </VisualState>
            </VisualStateGroup>
          </VisualStateManager.VisualStateGroups>
          <Border x:Name="Root" CornerRadius="10" Background="{TemplateBinding Background}"
                  BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
            <ContentPresenter Content="{TemplateBinding Content}" ContentTemplate="{TemplateBinding ContentTemplate}"
                              Padding="{TemplateBinding Padding}" HorizontalAlignment="Center" VerticalAlignment="Center"
                              Foreground="{TemplateBinding Foreground}" FontSize="{TemplateBinding FontSize}"
                              FontWeight="{TemplateBinding FontWeight}"/>
          </Border>
        </Grid>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="GlassPrimaryButton" TargetType="Button" BasedOn="{StaticResource GlassButtonBase}">
  <Setter Property="Background" Value="#F2FFFFFF"/>
  <Setter Property="Foreground" Value="#FF123F48"/>
  <Setter Property="BorderThickness" Value="0"/>
  <Setter Property="FontWeight" Value="SemiBold"/>
  <Setter Property="Height" Value="44"/>
</Style>

<Style x:Key="GlassGhostButton" TargetType="Button" BasedOn="{StaticResource GlassButtonBase}">
  <Setter Property="Height" Value="40"/>
</Style>

<Style x:Key="GlassLinkButton" TargetType="Button" BasedOn="{StaticResource GlassButtonBase}">
  <Setter Property="BorderThickness" Value="0"/>
  <Setter Property="HorizontalAlignment" Value="Right"/>
  <Setter Property="Padding" Value="8,4"/>
</Style>

<LinearGradientBrush x:Key="GlassEdge" StartPoint="0,0" EndPoint="1,1">
  <GradientStop Color="#99FFFFFF" Offset="0"/>
  <GradientStop Color="#22FFFFFF" Offset="0.5"/>
  <GradientStop Color="#66FFFFFF" Offset="1"/>
</LinearGradientBrush>
''';

  cLoginPageXaml = '''
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      RequestedTheme="Dark" Background="Transparent">
  <Grid.Resources>
%RES%
  </Grid.Resources>
  <Border Width="390" HorizontalAlignment="Center" VerticalAlignment="Center"
          CornerRadius="26" BorderThickness="1.5" BorderBrush="{StaticResource GlassEdge}">
    <Border.Background>
      <AcrylicBrush BackgroundSource="Backdrop" TintColor="#FF0E3A47" TintOpacity="0.35" FallbackColor="#CC1B3B46">%LUM%</AcrylicBrush>
    </Border.Background>
    <StackPanel Spacing="16" Margin="34,30,34,28">
      <TextBlock Text="Welcome back" FontSize="28" FontWeight="SemiBold" Foreground="White" HorizontalAlignment="Center"/>
      <TextBlock Text="Sign in to your account" Foreground="#CCFFFFFF" HorizontalAlignment="Center" FontSize="13"/>
      <TextBox x:Name="UserBox" Style="{StaticResource GlassTextBox}" PlaceholderText="Username"/>
      <PasswordBox x:Name="PassBox" Style="{StaticResource GlassPasswordBox}" PlaceholderText="Password"
                   IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
      <Grid>
        <CheckBox x:Name="RememberCheck" Content="Remember me" Foreground="White"/>
        <Button x:Name="ForgotButton" Content="Forgot password?" Style="{StaticResource GlassLinkButton}"/>
      </Grid>
      <Button x:Name="LoginButton" Content="Login" Style="{StaticResource GlassPrimaryButton}"/>
      <Button x:Name="RegisterButton" Content="Create an account" Style="{StaticResource GlassGhostButton}"/>
      <TextBlock x:Name="StatusText" Foreground="#E6FFFFFF" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"/>
    </StackPanel>
  </Border>
</Grid>
''';

  cRegisterPageXaml = '''
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      RequestedTheme="Dark" Background="Transparent">
  <Grid.Resources>
%RES%
  </Grid.Resources>
  <Border Width="410" HorizontalAlignment="Center" VerticalAlignment="Center"
          CornerRadius="26" BorderThickness="1.5" BorderBrush="{StaticResource GlassEdge}">
    <Border.Background>
      <AcrylicBrush BackgroundSource="Backdrop" TintColor="#FF0E3A47" TintOpacity="0.35" FallbackColor="#CC1B3B46">%LUM%</AcrylicBrush>
    </Border.Background>
    <ScrollViewer VerticalScrollBarVisibility="Auto">
      <StackPanel Spacing="14" Margin="34,26,34,26">
        <TextBlock Text="Create account" FontSize="28" FontWeight="SemiBold" Foreground="White" HorizontalAlignment="Center"/>
        <TextBlock Text="Create your local WinUI 2 account" Foreground="#CCFFFFFF" HorizontalAlignment="Center" FontSize="13"/>
        <TextBox x:Name="UserBox" Style="{StaticResource GlassTextBox}" PlaceholderText="Username"/>
        <TextBox x:Name="EmailBox" Style="{StaticResource GlassTextBox}" PlaceholderText="Recovery email" InputScope="EmailSmtpAddress"/>
        <TextBox x:Name="PictureBox" Style="{StaticResource GlassTextBox}" PlaceholderText="Picture path (optional)"/>
        <PasswordBox x:Name="PassBox" Style="{StaticResource GlassPasswordBox}" PlaceholderText="Password"
                     IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
        <PasswordBox x:Name="ConfirmBox" Style="{StaticResource GlassPasswordBox}" PlaceholderText="Confirm password"
                     IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
        <Button x:Name="RegisterButton" Content="Register" Style="{StaticResource GlassPrimaryButton}"/>
        <Button x:Name="BackButton" Content="Back to login" Style="{StaticResource GlassGhostButton}"/>
        <TextBlock x:Name="StatusText" Foreground="#E6FFFFFF" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"/>
      </StackPanel>
    </ScrollViewer>
  </Border>
</Grid>
''';

  cForgotPageXaml = '''
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      RequestedTheme="Dark" Background="Transparent">
  <Grid.Resources>
%RES%
  </Grid.Resources>
  <Border Width="410" HorizontalAlignment="Center" VerticalAlignment="Center"
          CornerRadius="26" BorderThickness="1.5" BorderBrush="{StaticResource GlassEdge}">
    <Border.Background>
      <AcrylicBrush BackgroundSource="Backdrop" TintColor="#FF0E3A47" TintOpacity="0.35" FallbackColor="#CC1B3B46">%LUM%</AcrylicBrush>
    </Border.Background>
    <StackPanel Spacing="14" Margin="34,30,34,28">
      <TextBlock Text="Reset password" FontSize="28" FontWeight="SemiBold" Foreground="White" HorizontalAlignment="Center"/>
      <TextBlock Text="Verify your username and recovery email, then choose a new password."
                 Foreground="#CCFFFFFF" TextWrapping="Wrap" TextAlignment="Center" FontSize="13"/>
      <TextBox x:Name="UserBox" Style="{StaticResource GlassTextBox}" PlaceholderText="Username"/>
      <TextBox x:Name="EmailBox" Style="{StaticResource GlassTextBox}" PlaceholderText="Recovery email"/>
      <PasswordBox x:Name="PassBox" Style="{StaticResource GlassPasswordBox}" PlaceholderText="New password"
                   IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
      <PasswordBox x:Name="ConfirmBox" Style="{StaticResource GlassPasswordBox}" PlaceholderText="Confirm new password"
                   IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
      <Button x:Name="ResetButton" Content="Reset password" Style="{StaticResource GlassPrimaryButton}"/>
      <Button x:Name="BackButton" Content="Back to login" Style="{StaticResource GlassGhostButton}"/>
      <TextBlock x:Name="StatusText" Foreground="#E6FFFFFF" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"/>
    </StackPanel>
  </Border>
</Grid>
''';

// Replaces %RES% and %LUM%; pass False to drop TintLuminosityOpacity (if the runtime refuses it).
function PageXaml(const ABody: string; AWithLuminosity: Boolean): string;

implementation

uses
  System.SysUtils;

function PageXaml(const ABody: string; AWithLuminosity: Boolean): string;
const
  // AcrylicBrush.TintLuminosityOpacity is a nullable double: XAML only accepts it as a property element.
  cLum = '<AcrylicBrush.TintLuminosityOpacity><x:Double>0.6</x:Double></AcrylicBrush.TintLuminosityOpacity>';
begin
  Result := StringReplace(ABody, '%RES%', cGlassResources, [rfReplaceAll]);
  if AWithLuminosity then
    Result := StringReplace(Result, '%LUM%', cLum, [rfReplaceAll])
  else
    Result := StringReplace(Result, '%LUM%', '', [rfReplaceAll]);
end;

end.
