unit Login.Pages;

interface

uses
  System.SysUtils;

const
  cLoginPageXaml = '''
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:media="using:Microsoft.UI.Xaml.Media"
      Background="Transparent">
  <Grid>
    <Border Width="390" HorizontalAlignment="Center" VerticalAlignment="Center"
            CornerRadius="26" BorderThickness="1.5">
      <Border.BorderBrush>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
          <GradientStop Color="#99FFFFFF" Offset="0"/>
          <GradientStop Color="#22FFFFFF" Offset="0.5"/>
          <GradientStop Color="#66FFFFFF" Offset="1"/>
        </LinearGradientBrush>
      </Border.BorderBrush>
      <Border.Background>
        <media:AcrylicBrush TintColor="#FF0E3A47" TintOpacity="0.35" FallbackColor="#CC1B3B46">%LUM%</media:AcrylicBrush>
      </Border.Background>
      <StackPanel Spacing="16" Margin="34,30,34,28">
        <TextBlock Text="Welcome back" FontSize="28" FontWeight="SemiBold" Foreground="White" HorizontalAlignment="Center"/>
        <TextBlock Text="Sign in to your account" Foreground="#CCFFFFFF" HorizontalAlignment="Center" FontSize="13"/>
        <TextBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="UserBox" PlaceholderText="Username" Foreground="White" FontSize="15" Height="42"/>
        <PasswordBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="PassBox" PlaceholderText="Password" Foreground="White" FontSize="15" Height="42"
                     IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
        <Grid>
          <CheckBox x:Name="RememberCheck" Content="Remember me" Foreground="White"/>
          <Button x:Name="ForgotButton" Content="Forgot password?" HorizontalAlignment="Right"
                  Background="Transparent" BorderThickness="0" Foreground="White"/>
        </Grid>
        <Button x:Name="LoginButton" Content="Login" Height="44" HorizontalAlignment="Stretch" CornerRadius="10" Background="#F2FFFFFF" Foreground="#FF123F48" FontWeight="SemiBold"/>
        <Button x:Name="RegisterButton" Content="Create an account" Height="40" HorizontalAlignment="Stretch" CornerRadius="10"
                Background="Transparent" BorderThickness="1" BorderBrush="#66FFFFFF" Foreground="White"/>
        <TextBlock x:Name="StatusText" Foreground="#E6FFFFFF" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"/>
      </StackPanel>
    </Border>
  </Grid>
</Grid>
''';

  cRegisterPageXaml = '''
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:media="using:Microsoft.UI.Xaml.Media"
      Background="Transparent">
  <Grid>
    <Border Width="410" HorizontalAlignment="Center" VerticalAlignment="Center"
            CornerRadius="26" BorderThickness="1.5">
      <Border.BorderBrush>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
          <GradientStop Color="#99FFFFFF" Offset="0"/>
          <GradientStop Color="#22FFFFFF" Offset="0.5"/>
          <GradientStop Color="#66FFFFFF" Offset="1"/>
        </LinearGradientBrush>
      </Border.BorderBrush>
      <Border.Background>
        <media:AcrylicBrush TintColor="#FF0E3A47" TintOpacity="0.35" FallbackColor="#CC1B3B46">%LUM%</media:AcrylicBrush>
      </Border.Background>
      <ScrollViewer VerticalScrollBarVisibility="Auto">
        <StackPanel Spacing="14" Margin="34,26,34,26">
          <TextBlock Text="Create account" FontSize="28" FontWeight="SemiBold" Foreground="White" HorizontalAlignment="Center"/>
          <TextBlock Text="Create your local WinUI 3 account" Foreground="#CCFFFFFF" HorizontalAlignment="Center" FontSize="13"/>
          <TextBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="UserBox" PlaceholderText="Username" Foreground="White"/>
          <TextBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="EmailBox" PlaceholderText="Recovery email" Foreground="White" InputScope="EmailSmtpAddress"/>
          <TextBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="PictureBox" PlaceholderText="Picture path (optional)" Foreground="White"/>
          <PasswordBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="PassBox" PlaceholderText="Password" Foreground="White"
                       IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
          <PasswordBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="ConfirmBox" PlaceholderText="Confirm password" Foreground="White"
                       IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
          <Button x:Name="RegisterButton" Content="Register" Height="44" HorizontalAlignment="Stretch" CornerRadius="10" Background="#F2FFFFFF" Foreground="#FF123F48" FontWeight="SemiBold"/>
          <Button x:Name="BackButton" HorizontalAlignment="Stretch" CornerRadius="10" Content="Back to login" Height="40"
                  Background="Transparent" BorderThickness="1" BorderBrush="#66FFFFFF" Foreground="White"/>
          <TextBlock x:Name="StatusText" Foreground="#E6FFFFFF" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"/>
        </StackPanel>
      </ScrollViewer>
    </Border>
  </Grid>
</Grid>
''';

  cForgotPageXaml = '''
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:media="using:Microsoft.UI.Xaml.Media"
      Background="Transparent">
  <Grid>
    <Border Width="410" HorizontalAlignment="Center" VerticalAlignment="Center"
            CornerRadius="26" BorderThickness="1.5">
      <Border.BorderBrush>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
          <GradientStop Color="#99FFFFFF" Offset="0"/>
          <GradientStop Color="#22FFFFFF" Offset="0.5"/>
          <GradientStop Color="#66FFFFFF" Offset="1"/>
        </LinearGradientBrush>
      </Border.BorderBrush>
      <Border.Background>
        <media:AcrylicBrush TintColor="#FF0E3A47" TintOpacity="0.35" FallbackColor="#CC1B3B46">%LUM%</media:AcrylicBrush>
      </Border.Background>
      <StackPanel Spacing="14" Margin="34,30,34,28">
        <TextBlock Text="Reset password" FontSize="28" FontWeight="SemiBold" Foreground="White" HorizontalAlignment="Center"/>
        <TextBlock Text="Verify your username and recovery email, then choose a new password."
                   Foreground="#CCFFFFFF" TextWrapping="Wrap" TextAlignment="Center" FontSize="13"/>
        <TextBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="UserBox" PlaceholderText="Username" Foreground="White"/>
        <TextBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="EmailBox" PlaceholderText="Recovery email" Foreground="White"/>
        <PasswordBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="PassBox" PlaceholderText="New password" Foreground="White"
                     IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
        <PasswordBox Background="#26FFFFFF" BorderBrush="#55FFFFFF" CornerRadius="10" x:Name="ConfirmBox" PlaceholderText="Confirm new password" Foreground="White"
                     IsPasswordRevealButtonEnabled="True" PasswordRevealMode="Peek"/>
        <Button x:Name="ResetButton" Content="Reset password" Height="44" HorizontalAlignment="Stretch" CornerRadius="10" Background="#F2FFFFFF" Foreground="#FF123F48" FontWeight="SemiBold"/>
        <Button x:Name="BackButton" HorizontalAlignment="Stretch" CornerRadius="10" Content="Back to login" Height="40"
                Background="Transparent" BorderThickness="1" BorderBrush="#66FFFFFF" Foreground="White"/>
        <TextBlock x:Name="StatusText" Foreground="#E6FFFFFF" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"/>
      </StackPanel>
    </Border>
  </Grid>
</Grid>
''';

// Replaces the %LUM% marker (TintLuminosityOpacity); call with False if the runtime refuses it.
function PageXaml(const ABody: string; AWithLuminosity: Boolean): string;

implementation

function PageXaml(const ABody: string; AWithLuminosity: Boolean): string;
const
  // AcrylicBrush.TintLuminosityOpacity is a nullable double: XAML only accepts it as a property element.
  cLum = '<media:AcrylicBrush.TintLuminosityOpacity><x:Double>0.6</x:Double></media:AcrylicBrush.TintLuminosityOpacity>';
begin
  if AWithLuminosity then
    Result := StringReplace(ABody, '%LUM%', cLum, [rfReplaceAll])
  else
    Result := StringReplace(ABody, '%LUM%', '', [rfReplaceAll]);
end;

end.
