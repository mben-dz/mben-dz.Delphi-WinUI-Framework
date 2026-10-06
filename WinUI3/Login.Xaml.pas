unit Login.Xaml;

interface

const
  cLoginXaml = '''
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      Background="#FF1B3B46">
  <Viewbox Stretch="UniformToFill">
    <Canvas Width="1600" Height="900">
      <Rectangle Width="1600" Height="900">
        <Rectangle.Fill>
          <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#FF2A8C9B" Offset="0"/>
            <GradientStop Color="#FF6CC3C0" Offset="0.45"/>
            <GradientStop Color="#FFF29B7C" Offset="0.8"/>
            <GradientStop Color="#FFF5B79A" Offset="1"/>
          </LinearGradientBrush>
        </Rectangle.Fill>
      </Rectangle>
      <Ellipse Canvas.Left="1090" Canvas.Top="470" Width="190" Height="190" Fill="#FFFFE3C2" Opacity="0.9"/>
      <Polygon Points="0,640 220,430 380,560 600,340 820,600 1000,500 1200,660 1600,560 1600,900 0,900"
               Fill="#FF3C8F8A" Opacity="0.85"/>
      <Polygon Points="0,760 260,600 480,720 760,560 1040,740 1300,620 1600,760 1600,900 0,900"
               Fill="#FF1F6B6F"/>
      <Polygon Points="0,840 340,730 640,820 980,720 1300,830 1600,760 1600,900 0,900"
               Fill="#FF123F48"/>
    </Canvas>
  </Viewbox>

  <Canvas Width="0" Height="0" HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False">
    <Ellipse Canvas.Left="-250" Canvas.Top="-230" Width="270" Height="270" Opacity="0.92">
      <Ellipse.Fill>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
          <GradientStop Color="#FFFF9A5B" Offset="0"/>
          <GradientStop Color="#FFFF4F7B" Offset="1"/>
        </LinearGradientBrush>
      </Ellipse.Fill>
    </Ellipse>
    <Ellipse Canvas.Left="40" Canvas.Top="20" Width="230" Height="230" Opacity="0.9">
      <Ellipse.Fill>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
          <GradientStop Color="#FF35F0D6" Offset="0"/>
          <GradientStop Color="#FF2A8DF4" Offset="1"/>
        </LinearGradientBrush>
      </Ellipse.Fill>
    </Ellipse>
  </Canvas>

  <ContentControl x:Name="PageHost" HorizontalAlignment="Stretch" VerticalAlignment="Stretch"
                  HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch">
    <ContentControl.ContentTransitions>
      <TransitionCollection>
        <EntranceThemeTransition FromVerticalOffset="24"/>
      </TransitionCollection>
    </ContentControl.ContentTransitions>
  </ContentControl>

  <Grid x:Name="TitleBar" Height="32" VerticalAlignment="Top" Background="Transparent">
    <StackPanel Orientation="Horizontal" Spacing="8" Margin="12,0,0,0" VerticalAlignment="Center">
      <TextBlock Text="&#xE77B;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="14"
                 Foreground="White" VerticalAlignment="Center"/>
      <TextBlock Text="WinUI 3 Login Demo" FontSize="12" Foreground="White" VerticalAlignment="Center"/>
    </StackPanel>
  </Grid>
</Grid>
''';

implementation

end.
