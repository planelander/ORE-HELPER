param(
    [switch]$ValidateOnly,
    [switch]$ValidateUi
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $projectRoot "data\mining-data.json"
$locationDataPath = Join-Path $projectRoot "data\mining-compiled.json"
$groundLocationDataPath = Join-Path $projectRoot "data\ground-mining-locations.json"
$tradeShipDataPath = Join-Path $projectRoot "data\trade-ships.json"
$data = Get-Content -Raw -LiteralPath $dataPath | ConvertFrom-Json
$locationData = if (Test-Path -LiteralPath $locationDataPath) {
    Get-Content -Raw -LiteralPath $locationDataPath | ConvertFrom-Json
} else {
    $null
}
$groundLocationData = if (Test-Path -LiteralPath $groundLocationDataPath) {
    Get-Content -Raw -LiteralPath $groundLocationDataPath | ConvertFrom-Json
} else {
    $null
}
$tradeShipData = Get-Content -Raw -LiteralPath $tradeShipDataPath | ConvertFrom-Json

if ($ValidateOnly) {
    $locationCount = if ($null -ne $locationData) { $locationData.locations.Count } else { 0 }
    Write-Output "Mining Helper data loaded: $($data.ores.Count) ores, $($data.signatures.Count) signatures, $locationCount locations, $($data.refineries.Count) refinery picks, $($data.ships.Count) ship configurations, patch $($data.patch)."
    exit 0
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ORE//OPS - Star Citizen Mining Helper"
        Width="1180" Height="760" MinWidth="980" MinHeight="650"
        WindowStartupLocation="CenterScreen"
        Background="#000000" Foreground="#F4EDF8"
        FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="Panel" Color="#000000"/>
        <SolidColorBrush x:Key="Panel2" Color="#08080D"/>
        <SolidColorBrush x:Key="Accent" Color="#FFB87A"/>
        <SolidColorBrush x:Key="Muted" Color="#AEA4BB"/>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#EEE5F4"/>
            <Setter Property="Background" Value="#242033"/>
            <Setter Property="BorderBrush" Value="#4C405D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,10"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="18">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.4"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3D3049"/>
                    <Setter Property="BorderBrush" Value="#FFB87A"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#09090D"/>
            <Setter Property="Foreground" Value="#F4EDF8"/>
            <Setter Property="BorderBrush" Value="#736080"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="CaretBrush" Value="#FFB87A"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#242033"/>
            <Setter Property="Foreground" Value="#C7B5EF"/>
            <Setter Property="BorderBrush" Value="#4C405D"/>
            <Setter Property="Padding" Value="8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid x:Name="ComboRoot" MinHeight="34">
                            <ToggleButton Focusable="False" ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="#242033" BorderBrush="#4C405D" BorderThickness="1" CornerRadius="4">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="30"/>
                                                </Grid.ColumnDefinitions>
                                                <Path Grid.Column="1" Data="M 0 0 L 5 5 L 10 0 Z" Fill="#C7B5EF"
                                                      HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="10,3,32,3"
                                              VerticalAlignment="Center"
                                              HorizontalAlignment="Left"
                                              TextElement.Foreground="#C7B5EF"/>
                            <Popup x:Name="Popup" Placement="Bottom"
                                   IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False"
                                   PopupAnimation="Slide">
                                <Border Background="#242033" BorderBrush="#736080" BorderThickness="1"
                                        CornerRadius="4" MinWidth="{Binding ActualWidth, ElementName=ComboRoot}"
                                        MaxHeight="320">
                                    <ScrollViewer Background="#242033" CanContentScroll="True">
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#242033"/>
            <Setter Property="Foreground" Value="#EEE5F4"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="ItemBackground" Background="#242033" Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="ItemBackground" Property="Background" Value="#3D3049"/>
                                <Setter Property="Foreground" Value="#C7B5EF"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemBackground" Property="Background" Value="#49334B"/>
                                <Setter Property="Foreground" Value="#C7B5EF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#101016"/>
            <Setter Property="Foreground" Value="#F4EDF8"/>
            <Setter Property="BorderBrush" Value="#4C405D"/>
            <Setter Property="RowBackground" Value="#101016"/>
            <Setter Property="AlternatingRowBackground" Value="#18151F"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#362D41"/>
            <Setter Property="VerticalGridLinesBrush" Value="#362D41"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="CanUserAddRows" Value="False"/>
            <Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="AutoGenerateColumns" Value="False"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#33283F"/>
            <Setter Property="Foreground" Value="#C7B5EF"/>
            <Setter Property="Padding" Value="10"/>
            <Setter Property="BorderBrush" Value="#4C405D"/>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Padding" Value="9,7"/>
            <Setter Property="BorderThickness" Value="0,0,0,1"/>
            <Setter Property="BorderBrush" Value="#362D41"/>
        </Style>
        <Style x:Key="MetricBar" TargetType="ProgressBar">
            <Setter Property="Height" Value="9"/>
            <Setter Property="Minimum" Value="0"/>
            <Setter Property="Maximum" Value="100"/>
            <Setter Property="Background" Value="#09090D"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Border Background="{TemplateBinding Background}" BorderBrush="#4C405D" BorderThickness="1" CornerRadius="4">
                            <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left" CornerRadius="3"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="LcarsNav" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="#C7B5EF"/>
            <Setter Property="Foreground" Value="#09090D"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Padding" Value="12,9"/>
            <Setter Property="FontFamily" Value="Bahnschrift SemiCondensed, Segoe UI"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="0" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Right" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="Tag" Value="Active">
                    <Setter Property="Background" Value="#FFB87A"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#F4EDF8"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions><RowDefinition Height="56"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="235"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Grid Grid.Row="0" Grid.ColumnSpan="2" Margin="12,12,12,8">
            <Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="42"/></Grid.ColumnDefinitions>
            <Border Background="#FFB87A" CornerRadius="22,0,0,22" Margin="0,0,4,0"/>
            <Border Grid.Column="1" Background="#FFB87A"/>
            <TextBlock Grid.Column="2" Text="MINING OPERATIONS" Foreground="#C7B5EF" Background="Black" FontFamily="Bahnschrift SemiCondensed, Segoe UI" FontSize="27" FontWeight="Bold" Padding="8,0" VerticalAlignment="Center"/>
            <Border Grid.Column="3" Background="#FFB87A" CornerRadius="0,22,22,0"/>
        </Grid>
        <Border Grid.Row="1" Grid.Column="0" Background="#000000" BorderBrush="#C7B5EF" BorderThickness="22,36,0,14" CornerRadius="54,0,0,40" Margin="12,8,0,12">
            <Grid Margin="8,12,8,10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="18"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <StackPanel>
                    <TextBlock Text="ORE//OPS" FontFamily="Bahnschrift SemiCondensed, Segoe UI" FontSize="28" FontWeight="Bold" Foreground="#FFB87A" HorizontalAlignment="Right"/>
                    <TextBlock Text="MINING COMPANION" FontSize="9" Foreground="#C7B5EF" Margin="2,3,0,0" HorizontalAlignment="Right"/>
                </StackPanel>
                <StackPanel Grid.Row="2">
                    <Button x:Name="NavDashboard" Style="{StaticResource LcarsNav}" Content="01   DASHBOARD" HorizontalContentAlignment="Left" Margin="0,0,0,8"/>
                    <Button x:Name="NavScanner" Style="{StaticResource LcarsNav}" Content="02   ROCK ASSESSMENT" HorizontalContentAlignment="Left" Margin="0,0,0,8"/>
                    <Button x:Name="NavSignature" Style="{StaticResource LcarsNav}" Content="03   SIGNATURE DECODER" HorizontalContentAlignment="Left" Margin="0,0,0,8"/>
                    <Button x:Name="NavCargo" Style="{StaticResource LcarsNav}" Content="04   CARGO" HorizontalContentAlignment="Left" Margin="0,0,0,8"/>
                    <Button x:Name="NavOres" Style="{StaticResource LcarsNav}" Content="05   ORE INDEX" HorizontalContentAlignment="Left" Margin="0,0,0,8"/>
                    <Button x:Name="NavRuns" Style="{StaticResource LcarsNav}" Content="06   RUN LOG" HorizontalContentAlignment="Left" Margin="0,0,0,8"/>
                    <Button x:Name="NavSettings" Style="{StaticResource LcarsNav}" Content="07   SETTINGS" HorizontalContentAlignment="Left"/>
                </StackPanel>
                <Border Grid.Row="4" Background="#000000" BorderBrush="#E99FAD" BorderThickness="0,8,0,0" CornerRadius="0" Padding="8">
                    <StackPanel>
                        <TextBlock Text="CREATOR" Foreground="#AEA4BB" FontSize="9"/>
                        <TextBlock Text="ADONIS ANUBIS" Foreground="#C7B5EF" FontWeight="Bold" Margin="0,3,0,0"/>
                        <TextBlock Text="FOR BLACKSHIELDS" Foreground="#5EE6A8" FontSize="10" FontWeight="SemiBold" Margin="0,2,0,10"/>
                        <Border Height="1" Background="#4C405D" Margin="0,0,0,10"/>
                        <TextBlock Text="LIVE DATA PROFILE" Foreground="#AEA4BB" FontSize="9"/>
                        <TextBlock x:Name="PatchLabel" Text="PATCH" Foreground="#FFB87A" FontWeight="Bold" Margin="0,4,0,0"/>
                        <TextBlock x:Name="UpdatedLabel" Text="Updated" Foreground="#5EE6A8" FontSize="10" FontWeight="SemiBold" Margin="0,2,0,0" TextWrapping="Wrap"/>
                        <TextBlock x:Name="LiveVersionStatus" Foreground="#AEA4BB" FontSize="9" Margin="0,4,0,0" TextWrapping="Wrap"/>
                        <Button x:Name="SnapshotButton" Content="DOWNLOAD SNAPSHOT" FontSize="9"
                                Padding="8,6" Margin="0,10,0,0" Background="#242033" BorderBrush="#746080"/>
                        <TextBlock x:Name="SnapshotStatus" Text="Ready" Foreground="#AEA4BB" FontSize="9"
                                   Margin="0,5,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <Grid Grid.Row="1" Grid.Column="1" Margin="20,8,22,16">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="18"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock x:Name="PageTitle" Text="OPERATIONS DASHBOARD" FontFamily="Bahnschrift SemiCondensed, Segoe UI" Foreground="#C7B5EF" FontSize="24" FontWeight="Bold"/>
                    <TextBlock x:Name="PageSubtitle" Text="Plan the rock. Protect the ship. Maximize the haul." Foreground="#AEA4BB" Margin="0,4,0,0"/>
                </StackPanel>
                <Border Grid.Column="1" Background="#E99FAD" CornerRadius="0,18,18,0" Padding="13,6" VerticalAlignment="Top">
                    <TextBlock Text="SYSTEM ONLINE" Foreground="#000000" FontFamily="Bahnschrift SemiCondensed, Segoe UI" FontSize="12" FontWeight="Bold"/>
                </Border>
            </Grid>

            <Grid Grid.Row="1" Height="12" VerticalAlignment="Center" IsHitTestVisible="False">
                <Grid.ColumnDefinitions><ColumnDefinition Width="3*"/><ColumnDefinition Width="*"/><ColumnDefinition Width="72"/></Grid.ColumnDefinitions>
                <Border Background="#FFB87A" CornerRadius="4,0,0,4" Margin="0,0,6,0"/>
                <Border Grid.Column="1" Background="#C7B5EF" Margin="0,0,6,0"/>
                <Border Grid.Column="2" Background="#E99FAD" CornerRadius="0,4,4,0"/>
            </Grid>
            <!-- Dashboard -->
            <Grid x:Name="DashboardPage" Grid.Row="2">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="18"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="220"/>
                    </Grid.ColumnDefinitions>
                    <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="18" Margin="0,0,12,0">
                        <StackPanel>
                            <TextBlock Text="TOP 4 REFINED / aUEC PER SCU" Foreground="#AEA4BB" FontSize="10"/>
                            <ItemsControl x:Name="TopOreBuyers" Margin="0,8,0,0">
                                <ItemsControl.ItemTemplate>
                                    <DataTemplate>
                                        <StackPanel Margin="0,0,0,8">
                                            <Grid>
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="{Binding ore}" Foreground="#C7B5EF" FontSize="12" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" Margin="0,0,8,0"/>
                                                <TextBlock Grid.Column="1" Text="{Binding priceDisplay}" Foreground="#F6C85F" FontSize="14" FontWeight="Bold"/>
                                            </Grid>
                                            <TextBlock Text="{Binding buyer}" ToolTip="{Binding buyer}" Foreground="#C1B6CD" FontSize="10" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                        </StackPanel>
                                    </DataTemplate>
                                </ItemsControl.ItemTemplate>
                            </ItemsControl>
                            <TextBlock x:Name="OreBuyerStatus" Foreground="#AEA4BB" FontSize="9" TextWrapping="Wrap"/>
                            <Button x:Name="RefreshOreBuyers" Content="REFRESH BUYER PRICES" FontSize="9" Padding="8,5" Margin="0,8,0,0" HorizontalAlignment="Left"/>
                        </StackPanel>
                    </Border>
                    <Border x:Name="RefineryJobCard" Grid.Column="1" Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="14,10" Margin="0,0,12,0">
                        <StackPanel>
                            <TextBlock Text="REFINERY JOBS / RUN LOG" Foreground="#AEA4BB" FontSize="9"/>
                            <TextBlock x:Name="RefineryJobStatus" Text="No active job" Foreground="#C7B5EF" FontSize="18" FontWeight="Bold" TextWrapping="Wrap" Margin="0,5,0,0"/>
                            <TextBlock x:Name="RefineryJobDetail" Text="Set timers in the Run Log" Foreground="#C1B6CD" FontSize="10" TextTrimming="CharacterEllipsis" Margin="0,3,0,0"/>
                        </StackPanel>
                    </Border>
                </Grid>
                <Border Grid.Row="3" Background="{StaticResource Panel}" BorderBrush="#4C405D" BorderThickness="1" CornerRadius="14,4,14,4" Padding="12,6" Margin="0,10,0,0" HorizontalAlignment="Right">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="RECORDED RUNS" Foreground="#AEA4BB" FontSize="9" VerticalAlignment="Center"/>
                        <TextBlock x:Name="RunCount" Text="0" Foreground="#5EE6A8" FontSize="15" FontWeight="Bold" Margin="10,0" VerticalAlignment="Center"/>
                        <TextBlock Text="saved on this PC" Foreground="#C1B6CD" FontSize="9" VerticalAlignment="Center"/>
                    </StackPanel>
                </Border>
                <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="14"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel>
                        <TextBlock Text="TOP REFINERY BY SYSTEM" FontSize="15" FontWeight="SemiBold" Foreground="#C7B5EF"/>
                        <TextBlock Text="One recommended refinery from each playable system, based on current yield profiles and tracked use." Foreground="#AEA4BB" Margin="0,4,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Row="2">
                    <UniformGrid Columns="3" Height="185" VerticalAlignment="Top">
                        <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="15" Margin="0,0,10,0">
                            <StackPanel>
                                <TextBlock Text="STANTON" Foreground="#AEA4BB" FontSize="9" FontWeight="Bold"/>
                                <TextBlock x:Name="StantonRefineryName" Text="-" Foreground="#FFB87A" FontSize="18" FontWeight="Bold" Margin="0,7,0,2"/>
                                <TextBlock x:Name="StantonRefineryRating" Text="-" Foreground="#5EE6A8" FontSize="8" FontWeight="Bold"/>
                                <Border Height="1" Background="#4C405D" Margin="0,9,0,8"/>
                                <TextBlock x:Name="StantonRefineryHighlight" Text="-" Foreground="#F6C85F" FontSize="11" TextWrapping="Wrap" LineHeight="16"/>
                                <TextBlock x:Name="StantonRefineryNote" Text="-" Foreground="#C1B6CD" FontSize="11" TextWrapping="Wrap" Margin="0,8,0,0" LineHeight="16"/>
                            </StackPanel>
                        </Border>
                        <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="15" Margin="5,0">
                            <StackPanel>
                                <TextBlock Text="PYRO" Foreground="#AEA4BB" FontSize="9" FontWeight="Bold"/>
                                <TextBlock x:Name="PyroRefineryName" Text="-" Foreground="#ED6A5A" FontSize="18" FontWeight="Bold" Margin="0,7,0,2"/>
                                <TextBlock x:Name="PyroRefineryRating" Text="-" Foreground="#5EE6A8" FontSize="8" FontWeight="Bold"/>
                                <Border Height="1" Background="#4C405D" Margin="0,9,0,8"/>
                                <TextBlock x:Name="PyroRefineryHighlight" Text="-" Foreground="#F6C85F" FontSize="11" TextWrapping="Wrap" LineHeight="16"/>
                                <TextBlock x:Name="PyroRefineryNote" Text="-" Foreground="#C1B6CD" FontSize="11" TextWrapping="Wrap" Margin="0,8,0,0" LineHeight="16"/>
                            </StackPanel>
                        </Border>
                        <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="15" Margin="10,0,0,0">
                            <StackPanel>
                                <TextBlock Text="NYX" Foreground="#AEA4BB" FontSize="9" FontWeight="Bold"/>
                                <TextBlock x:Name="NyxRefineryName" Text="-" Foreground="#CDB4DB" FontSize="18" FontWeight="Bold" Margin="0,7,0,2"/>
                                <TextBlock x:Name="NyxRefineryRating" Text="-" Foreground="#5EE6A8" FontSize="8" FontWeight="Bold"/>
                                <Border Height="1" Background="#4C405D" Margin="0,9,0,8"/>
                                <TextBlock x:Name="NyxRefineryHighlight" Text="-" Foreground="#F6C85F" FontSize="11" TextWrapping="Wrap" LineHeight="16"/>
                                <TextBlock x:Name="NyxRefineryNote" Text="-" Foreground="#C1B6CD" FontSize="11" TextWrapping="Wrap" Margin="0,8,0,0" LineHeight="16"/>
                            </StackPanel>
                        </Border>
                    </UniformGrid>
                    <UniformGrid Columns="3" Margin="0,14,0,0">
                        <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="15" Margin="0,0,10,0">
                            <StackPanel>
                                <TextBlock Text="CASTRA" Foreground="#AEA4BB" FontSize="9" FontWeight="Bold"/>
                                <TextBlock Text="Coming Soon" Foreground="#C7B5EF" FontSize="18" FontWeight="Bold" Margin="0,7,0,2"/>
                            </StackPanel>
                        </Border>
                        <Border/>
                        <Border/>
                    </UniformGrid>
                    </StackPanel>
                </Grid>
            </ScrollViewer></Grid>

            <!-- Signature decoder -->
            <Grid x:Name="SignaturePage" Grid.Row="2" Visibility="Collapsed">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width=".9*"/>
                    <ColumnDefinition Width="20"/>
                    <ColumnDefinition Width="1.25*"/>
                </Grid.ColumnDefinitions>
                <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="22">
                    <StackPanel>
                        <TextBlock Text="RS SIGNATURE" FontSize="15" FontWeight="SemiBold" Foreground="#C7B5EF"/>
                        <TextBlock Text="Enter the number shown beside the scan return." Foreground="#AEA4BB" Margin="0,4,0,22" TextWrapping="Wrap"/>
                        <TextBlock Text="SCANNER VALUE" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                        <TextBox x:Name="SignatureInput" Text="10755" FontSize="24" FontWeight="SemiBold" Padding="12"/>
                        <Button x:Name="DecodeSignatureButton" Content="IDENTIFY ROCK" Background="#49334B" BorderBrush="#FFB87A" Foreground="#C7B5EF" Margin="0,14,0,0"/>
                        <Button x:Name="ToggleScanOverlay" Content="START OVERLAY (F3)" Margin="0,8,0,0"/>
                        <TextBlock x:Name="ScanOverlayStatus" Text="Automatically reads the scan marker in the game HUD. F3 toggles the overlay. Use borderless/windowed mode." TextWrapping="Wrap" Foreground="#AEA4BB" FontSize="11" Margin="0,8,0,0"/>
                        <Border Background="#09090D" CornerRadius="18" Padding="15" Margin="0,24,0,0">
                            <StackPanel>
                                <TextBlock Text="HOW IT WORKS" Foreground="#AEA4BB" FontSize="9"/>
                                <TextBlock Text="In patch 4.10, most scan returns are the base signature multiplied by the number of rocks in the cluster. The decoder checks counts from 1 to 10 with a small tolerance." TextWrapping="Wrap" Foreground="#C1B6CD" Margin="0,8,0,0" LineHeight="20"/>
                            </StackPanel>
                        </Border>
                        <TextBlock Text="Ground-deposit signatures can indicate size without identifying the exact gem." Foreground="#E9C46A" TextWrapping="Wrap" Margin="0,15,0,0" FontSize="11"/>
                    </StackPanel>
                </Border>
                <Grid Grid.Column="2">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="12"/>
                        <RowDefinition Height=".75*"/>
                        <RowDefinition Height="12"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="1.1*"/>
                    </Grid.RowDefinitions>
                    <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="22">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel>
                                <TextBlock Text="BEST MATCH" Foreground="#AEA4BB" FontSize="10"/>
                                <TextBlock x:Name="SignatureResultName" Text="AWAITING SCAN" Foreground="#FFB87A" FontSize="27" FontWeight="Bold" Margin="0,10,0,3"/>
                                <TextBlock x:Name="SignatureResultDetail" Text="Enter an RS signature to identify the return." Foreground="#C1B6CD"/>
                            </StackPanel>
                            <Border Grid.Column="1" Background="#201C2B" CornerRadius="18" Padding="13,8" VerticalAlignment="Center">
                                <TextBlock x:Name="SignatureConfidence" Text="READY" Foreground="#C7B5EF" FontWeight="Bold" FontSize="10"/>
                            </Border>
                        </Grid>
                    </Border>
                    <DataGrid x:Name="SignatureGrid" Grid.Row="2" AlternationCount="2">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="POSSIBLE MATCH" Binding="{Binding name}" Width="*"/>
                            <DataGridTextColumn Header="TYPE" Binding="{Binding category}" Width="145"/>
                            <DataGridTextColumn Header="ROCKS" Binding="{Binding count}" Width="70"/>
                            <DataGridTextColumn Header="BASE RS" Binding="{Binding baseDisplay}" Width="90"/>
                            <DataGridTextColumn Header="ERROR" Binding="{Binding errorDisplay}" Width="80"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    <Grid Grid.Row="4">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="137"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="140"/>
                        </Grid.ColumnDefinitions>
                        <ComboBox x:Name="MiningMethodFilter" Padding="7,4" Margin="0,0,12,0"/>
                        <ComboBox x:Name="MineralFilter" Grid.Column="1" Padding="7,4" Margin="0,0,12,0"/>
                        <ComboBox x:Name="SystemFilter" Grid.Column="2" Padding="7,4"/>
                    </Grid>
                    <DataGrid x:Name="LocationGrid" Grid.Row="5" AlternationCount="2" Margin="0,8,0,0">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="SYSTEM" Binding="{Binding system}" Width="85"/>
                            <DataGridTextColumn Header="LOCATION" Binding="{Binding location}" Width="*"/>
                            <DataGridTextColumn Header="CHANCE" Binding="{Binding chanceDisplay}" Width="85"/>
                            <DataGridTextColumn Header="METHOD" Binding="{Binding method}" Width="95"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    <TextBlock x:Name="LocationEmptyState" Grid.Row="5" Text="No location percentages are available in the current snapshot for this mining method."
                               Visibility="Collapsed" Foreground="#AEA4BB" TextAlignment="Center" TextWrapping="Wrap"
                               HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="420" Margin="20"/>
                </Grid>
            </Grid>

            <!-- Rock assessment -->
            <Grid x:Name="ScannerPage" Grid.Row="2" Visibility="Collapsed">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="1.05*"/>
                    <ColumnDefinition Width="20"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="22">
                    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <StackPanel Margin="0,0,8,0">
                            <TextBlock Text="SHIP FIT" FontSize="15" FontWeight="SemiBold" Foreground="#C7B5EF"/>
                            <TextBlock Text="Configure your ship and save your favorite mining fits." Foreground="#AEA4BB" Margin="0,4,0,14" TextWrapping="Wrap"/>
                            <TextBlock Text="SAVED SHIP PRESETS" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <ComboBox x:Name="FitPresetSelect" DisplayMemberPath="label" Margin="0,0,0,6"/>
                            <TextBlock Text="PRESET NAME" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,4"/>
                            <TextBox x:Name="FitPresetName" MaxLength="60" ToolTip="Preset name, for example: Best solo mining" Margin="0,0,0,6"/>
                            <UniformGrid Columns="3" Margin="0,0,0,6">
                                <Button x:Name="SaveFitPreset" Content="SAVE / UPDATE" FontSize="9" Padding="5,8" Margin="0,0,3,0"/>
                                <Button x:Name="LoadFitPreset" Content="LOAD" FontSize="9" Padding="5,8" Margin="3,0" IsEnabled="False"/>
                                <Button x:Name="DeleteFitPreset" Content="DELETE" FontSize="9" Padding="5,8" Margin="3,0,0,0" IsEnabled="False"/>
                            </UniformGrid>
                            <TextBlock x:Name="FitPresetStatus" Text="Name your fit, then save. Same ship and name updates it." Foreground="#AEA4BB" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,14"/>
                            <TextBlock Text="MINING PLATFORM" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <ComboBox x:Name="ShipSelect" Margin="0,0,0,10"/>
                            
                            <Border x:Name="Loadout1Panel" Background="#09090D" BorderBrush="#4C405D" BorderThickness="1" CornerRadius="18" Padding="10" Margin="0,0,0,8">
                                <StackPanel>
                                    <Grid Margin="0,0,0,5">
                                        <TextBlock x:Name="Head1Label" Text="MINING HEAD" Foreground="#C7B5EF" FontSize="10" FontWeight="Bold" VerticalAlignment="Center"/>
                                        <Button x:Name="Head1Toggle" Content="ACTIVE" Width="78" Padding="8,3" FontSize="9" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <ComboBox x:Name="Head1Select" Margin="0,0,0,7"/>
                                    <TextBlock x:Name="ModuleLabel1" Text="ATTACHED MODULES" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <UniformGrid x:Name="ModuleGrid1" Columns="3">
                                        <ComboBox x:Name="Head1Module1" Margin="0,0,3,0"/>
                                        <ComboBox x:Name="Head1Module2" Margin="2,0"/>
                                        <ComboBox x:Name="Head1Module3" Margin="3,0,0,0"/>
                                    </UniformGrid>
                                </StackPanel>
                            </Border>

                            <Border x:Name="Loadout2Panel" Visibility="Collapsed" Background="#09090D" BorderBrush="#4C405D" BorderThickness="1" CornerRadius="18" Padding="10" Margin="0,0,0,8">
                                <StackPanel>
                                    <Grid Margin="0,0,0,5">
                                        <TextBlock Text="PORT MINING HEAD" Foreground="#C7B5EF" FontSize="10" FontWeight="Bold" VerticalAlignment="Center"/>
                                        <Button x:Name="Head2Toggle" Content="ACTIVE" Width="78" Padding="8,3" FontSize="9" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <ComboBox x:Name="Head2Select" Margin="0,0,0,7"/>
                                    <TextBlock x:Name="ModuleLabel2" Text="ATTACHED MODULES" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <UniformGrid x:Name="ModuleGrid2" Columns="3">
                                        <ComboBox x:Name="Head2Module1" Margin="0,0,3,0"/>
                                        <ComboBox x:Name="Head2Module2" Margin="2,0"/>
                                        <ComboBox x:Name="Head2Module3" Margin="3,0,0,0"/>
                                    </UniformGrid>
                                </StackPanel>
                            </Border>

                            <Border x:Name="Loadout3Panel" Visibility="Collapsed" Background="#09090D" BorderBrush="#4C405D" BorderThickness="1" CornerRadius="18" Padding="10" Margin="0,0,0,8">
                                <StackPanel>
                                    <Grid Margin="0,0,0,5">
                                        <TextBlock Text="STARBOARD MINING HEAD" Foreground="#C7B5EF" FontSize="10" FontWeight="Bold" VerticalAlignment="Center"/>
                                        <Button x:Name="Head3Toggle" Content="ACTIVE" Width="78" Padding="8,3" FontSize="9" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <ComboBox x:Name="Head3Select" Margin="0,0,0,7"/>
                                    <TextBlock x:Name="ModuleLabel3" Text="ATTACHED MODULES" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <UniformGrid x:Name="ModuleGrid3" Columns="3">
                                        <ComboBox x:Name="Head3Module1" Margin="0,0,3,0"/>
                                        <ComboBox x:Name="Head3Module2" Margin="2,0"/>
                                        <ComboBox x:Name="Head3Module3" Margin="3,0,0,0"/>
                                    </UniformGrid>
                                </StackPanel>
                            </Border>

                            <TextBlock x:Name="LoadoutStats" Text="Select a mining loadout." Foreground="#5EE6A8" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,12"/>
                            <TextBlock Text="ROCK MASS" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <TextBox x:Name="RockMass" Text="5000" Margin="0,0,0,10"/>
                            <TextBlock Text="RESISTANCE %" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <TextBox x:Name="Resistance" Text="25" Margin="0,0,0,10"/>
                            <TextBlock Text="INSTABILITY (0-10)" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <TextBox x:Name="Instability" Text="3.5" Margin="0,0,0,14"/>
                            <Button x:Name="AssessButton" Content="ASSESS DEPOSIT" Background="#49334B" BorderBrush="#FFB87A" Foreground="#C7B5EF"/>
                        </StackPanel>
                    </ScrollViewer>
                </Border>
                <Border Grid.Column="2" Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="24">
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="BREAKABILITY ESTIMATE" Foreground="#AEA4BB" FontSize="10" HorizontalAlignment="Center"/>
                        <TextBlock x:Name="AssessmentStatus" Text="READY TO ASSESS" Foreground="#FFB87A" FontSize="27" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,16,0,6"/>
                        <TextBlock x:Name="AssessmentScore" Text="Enter scan values to begin." Foreground="#C1B6CD" HorizontalAlignment="Center"/>
                        <Border Background="#09090D" BorderBrush="#4C405D" BorderThickness="1" CornerRadius="18" Padding="12" Margin="0,18,0,0">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="GADGET" Foreground="#F4EDF8" FontWeight="Bold" VerticalAlignment="Center"/>
                                <ComboBox x:Name="GadgetSelect" Grid.Column="1" Width="200" HorizontalAlignment="Right"/>
                            </Grid>
                        </Border>
                        <Border Background="#0A1720" BorderBrush="#4C405D" BorderThickness="1" CornerRadius="18" Padding="16" Margin="0,10,0,0">
                            <StackPanel>
                                <Grid>
                                    <TextBlock Text="LOADOUT STATS" Foreground="#F4EDF8" FontWeight="Bold"/>
                                    <TextBlock x:Name="EffectiveDps" Text="0 EFF. DPS" Foreground="#FFB87A" FontSize="16" FontWeight="Bold" HorizontalAlignment="Right"/>
                                </Grid>
                                <TextBlock x:Name="ExtractionStats" Text="Extraction: 0 DPS | Range: -" Foreground="#526D7A" Margin="0,8,0,0"/>
                                <TextBlock x:Name="GadgetBenefit" Text="Gadget: no modifiers" Foreground="#AEA4BB" FontSize="10" Margin="0,5,0,14"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="118"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="2"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="58"/>
                                    </Grid.ColumnDefinitions>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="11"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="11"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="11"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <Border Grid.Column="2" Grid.RowSpan="7" Width="1" Background="#736080"/>

                                    <TextBlock Text="INSTABILITY" Foreground="#526D7A" FontSize="10" VerticalAlignment="Center"/>
                                    <Border x:Name="InstabilityNegative" Grid.Column="1" Height="9" Width="0" Background="#ED6A5A" CornerRadius="4" HorizontalAlignment="Right"/>
                                    <Border x:Name="InstabilityPositive" Grid.Column="3" Height="9" Width="0" Background="#5EE6A8" CornerRadius="4" HorizontalAlignment="Left"/>
                                    <TextBlock x:Name="InstabilityGraphValue" Grid.Column="4" Text="0%" Foreground="#AEA4BB" HorizontalAlignment="Right"/>

                                    <TextBlock Grid.Row="2" Text="OPT. WINDOW" Foreground="#526D7A" FontSize="10" VerticalAlignment="Center"/>
                                    <Border x:Name="WindowNegative" Grid.Row="2" Grid.Column="1" Height="9" Width="0" Background="#ED6A5A" CornerRadius="4" HorizontalAlignment="Right"/>
                                    <Border x:Name="WindowPositive" Grid.Row="2" Grid.Column="3" Height="9" Width="0" Background="#5EE6A8" CornerRadius="4" HorizontalAlignment="Left"/>
                                    <TextBlock x:Name="WindowGraphValue" Grid.Row="2" Grid.Column="4" Text="0%" Foreground="#AEA4BB" HorizontalAlignment="Right"/>

                                    <TextBlock Grid.Row="4" Text="RESISTANCE" Foreground="#526D7A" FontSize="10" VerticalAlignment="Center"/>
                                    <Border x:Name="ResistanceNegative" Grid.Row="4" Grid.Column="1" Height="9" Width="0" Background="#ED6A5A" CornerRadius="4" HorizontalAlignment="Right"/>
                                    <Border x:Name="ResistancePositive" Grid.Row="4" Grid.Column="3" Height="9" Width="0" Background="#5EE6A8" CornerRadius="4" HorizontalAlignment="Left"/>
                                    <TextBlock x:Name="ResistanceGraphValue" Grid.Row="4" Grid.Column="4" Text="0%" Foreground="#AEA4BB" HorizontalAlignment="Right"/>

                                    <TextBlock Grid.Row="6" Text="INERT FILTERING" Foreground="#526D7A" FontSize="10" VerticalAlignment="Center"/>
                                    <Border x:Name="FilterNegative" Grid.Row="6" Grid.Column="1" Height="9" Width="0" Background="#ED6A5A" CornerRadius="4" HorizontalAlignment="Right"/>
                                    <Border x:Name="FilterPositive" Grid.Row="6" Grid.Column="3" Height="9" Width="0" Background="#5EE6A8" CornerRadius="4" HorizontalAlignment="Left"/>
                                    <TextBlock x:Name="FilterGraphValue" Grid.Row="6" Grid.Column="4" Text="0%" Foreground="#AEA4BB" HorizontalAlignment="Right"/>
                                </Grid>
                            </StackPanel>
                        </Border>
                        <Border Background="#09090D" CornerRadius="18" Padding="16" Margin="0,14,0,0">
                            <StackPanel>
                                <TextBlock x:Name="AssessmentDetail" Text="This is a planning estimate. Choose your platform, mining head, and installed modules, then enter the deposit scan values." TextWrapping="Wrap" Foreground="#C1B6CD" TextAlignment="Center" LineHeight="21"/>
                            </StackPanel>
                        </Border>
                        <TextBlock Text="Never treat this score as an in-game safety guarantee." Foreground="#AEA4BB" FontSize="10" HorizontalAlignment="Center" Margin="0,15,0,0"/>
                    </StackPanel>
                </Border>
            </Grid>

            <!-- Cargo calculator -->
            <Grid x:Name="CargoPage" Grid.Row="2" Visibility="Collapsed">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="12"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <UniformGrid Columns="2" Width="350" HorizontalAlignment="Left">
                    <Button x:Name="CargoValueModeButton" Content="MINING VALUE" Background="#49334B" BorderBrush="#FFB87A" Foreground="#C7B5EF" Margin="0,0,5,0"/>
                    <Button x:Name="TradeModeButton" Content="TRADE ROUTES" Margin="5,0,0,0"/>
                </UniformGrid>

                <Grid x:Name="CargoValuePanel" Grid.Row="2">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.05*"/>
                        <ColumnDefinition Width="20"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="16" VerticalAlignment="Top">
                        <StackPanel>
                            <TextBlock Text="HAUL DETAILS" FontSize="15" FontWeight="SemiBold" Foreground="#C7B5EF"/>
                            <TextBlock Text="Estimate gross value before refinery fees or hauling costs." Foreground="#AEA4BB" Margin="0,3,0,12"/>
                            <TextBlock Text="PRIMARY ORE" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <ComboBox x:Name="CargoOreSelect" Margin="0,0,0,9"/>
                            <TextBlock Text="TOTAL CARGO (SCU)" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <TextBox x:Name="CargoScu" Text="32" Margin="0,0,0,9"/>
                            <TextBlock Text="ORE CONTENT %" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <TextBox x:Name="CargoPurity" Text="65" Margin="0,0,0,9"/>
                            <TextBlock Text="REFINERY YIELD %" Foreground="#AEA4BB" FontSize="10" Margin="0,0,0,6"/>
                            <TextBox x:Name="RefineryYield" Text="92" Margin="0,0,0,12"/>
                            <Button x:Name="CalculateButton" Content="CALCULATE VALUE" Background="#49334B" BorderBrush="#FFB87A" Foreground="#C7B5EF"/>
                        </StackPanel>
                    </Border>
                    <StackPanel Grid.Column="2">
                        <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="22" Margin="0,0,0,14">
                            <StackPanel>
                                <TextBlock Text="RAW SALE ESTIMATE" Foreground="#AEA4BB" FontSize="10"/>
                                <TextBlock x:Name="RawValue" Text="0 aUEC" Foreground="#C7B5EF" FontSize="29" FontWeight="Bold" Margin="0,10,0,3"/>
                                <TextBlock x:Name="RawDetail" Text="-" Foreground="#C1B6CD"/>
                            </StackPanel>
                        </Border>
                        <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="22" Margin="0,0,0,14">
                            <StackPanel>
                                <TextBlock Text="REFINED GROSS ESTIMATE" Foreground="#AEA4BB" FontSize="10"/>
                                <TextBlock x:Name="RefinedValue" Text="0 aUEC" Foreground="#5EE6A8" FontSize="29" FontWeight="Bold" Margin="0,10,0,3"/>
                                <TextBlock x:Name="RefinedDetail" Text="-" Foreground="#C1B6CD"/>
                            </StackPanel>
                        </Border>
                        <Border Background="#251B16" BorderBrush="#6E4C2A" BorderThickness="1" CornerRadius="22,6,22,6" Padding="16">
                            <TextBlock Text="Refined gross excludes refinery fees, method bonuses, hauling costs, demand limits, and price movement." TextWrapping="Wrap" Foreground="#E9C46A"/>
                        </Border>
                    </StackPanel>
                </Grid>

                <Grid x:Name="TradeRoutesPanel" Grid.Row="2" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="12"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="16">
                        <StackPanel>
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="10"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="230"/>
                                    <ColumnDefinition Width="90"/>
                                    <ColumnDefinition Width="130"/>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Margin="0,0,10,0">
                                    <TextBlock Text="SHIP / CARGO GRID" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <ComboBox x:Name="TradeShipSelect" Padding="7,4"/>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Margin="0,0,10,0">
                                    <TextBlock Text="CARGO SCU" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <TextBox x:Name="TradeCargoScu" Text="64"/>
                                </StackPanel>
                                <StackPanel Grid.Column="2" Margin="0,0,10,0">
                                    <TextBlock Text="MAX INVESTMENT" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <TextBox x:Name="TradeBudget" Text="100000"/>
                                </StackPanel>
                                <StackPanel Grid.Column="3" Margin="0,0,10,0">
                                    <TextBlock Text="CATEGORY" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <ComboBox x:Name="TradeCategorySelect" Padding="7,4"/>
                                </StackPanel>
                                <StackPanel Grid.Column="4" Margin="0,0,10,0">
                                    <TextBlock Text="ITEM TO TRADE" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <ComboBox x:Name="TradeItemSelect" Padding="7,4"/>
                                </StackPanel>
                                <StackPanel Grid.Row="2" Grid.Column="0" Margin="0,0,10,0">
                                    <TextBlock Text="SYSTEM" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <ComboBox x:Name="TradeSystemSelect" Padding="7,4"/>
                                </StackPanel>
                                <StackPanel Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="2" Margin="0,0,10,0">
                                    <TextBlock Text="BUY TERMINAL (OPTIONAL)" Foreground="#AEA4BB" FontSize="9" Margin="0,0,0,5"/>
                                    <TextBox x:Name="TradeOriginFilter" ToolTip="Example: Everus Harbor"/>
                                </StackPanel>
                                <Button x:Name="FindTradeRoutesButton" Grid.Row="2" Grid.Column="4" Width="155" HorizontalAlignment="Right" Content="FIND LIVE ROUTES" Background="#49334B" BorderBrush="#FFB87A" Foreground="#C7B5EF" VerticalAlignment="Bottom"/>
                            </Grid>
                            <TextBlock x:Name="TradeStatus" Text="Live community pricing supplied by UEX. Enter capacity and budget, then search." Foreground="#AEA4BB" FontSize="10" Margin="0,10,0,0"/>
                        </StackPanel>
                    </Border>
                    <DataGrid x:Name="TradeRoutesGrid" Grid.Row="2" AlternationCount="2">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="COMMODITY" Binding="{Binding commodity}" Width="115"/>
                            <DataGridTextColumn Header="BUY AT" Binding="{Binding buyAt}" Width="*">
                                <DataGridTextColumn.ElementStyle>
                                    <Style TargetType="TextBlock">
                                        <Setter Property="ToolTip" Value="{Binding buyAt}"/>
                                    </Style>
                                </DataGridTextColumn.ElementStyle>
                            </DataGridTextColumn>
                            <DataGridTextColumn Header="BUY / SCU" Binding="{Binding buyDisplay}" Width="90"/>
                            <DataGridTextColumn Header="SELL AT" Binding="{Binding sellAt}" Width="*">
                                <DataGridTextColumn.ElementStyle>
                                    <Style TargetType="TextBlock">
                                        <Setter Property="ToolTip" Value="{Binding sellAt}"/>
                                    </Style>
                                </DataGridTextColumn.ElementStyle>
                            </DataGridTextColumn>
                            <DataGridTextColumn Header="SELL / SCU" Binding="{Binding sellDisplay}" Width="90"/>
                            <DataGridTextColumn Header="SCU" Binding="{Binding cargoDisplay}" Width="60"/>
                            <DataGridTextColumn Header="ROI" Binding="{Binding roiDisplay}" Width="65"/>
                            <DataGridTextColumn Header="INVEST" Binding="{Binding investmentDisplay}" Width="95"/>
                            <DataGridTextColumn Header="PROFIT" Binding="{Binding profitDisplay}" Width="100"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>
            </Grid>

            <!-- Ore index -->
            <Grid x:Name="OresPage" Grid.Row="2" Visibility="Collapsed">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="12"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="220"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Text="Values are estimated aUEC per SCU. Sort by clicking a column header." Foreground="#AEA4BB" VerticalAlignment="Center"/>
                    <TextBox x:Name="OreSearch" Grid.Column="1" Text="" ToolTip="Filter by ore name or code"/>
                </Grid>
                <DataGrid x:Name="OreGrid" Grid.Row="2" AlternationCount="2">
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="ORE" Binding="{Binding name}" Width="*"/>
                        <DataGridTextColumn Header="CODE" Binding="{Binding code}" Width="90"/>
                        <DataGridTextColumn Header="TIER" Binding="{Binding tier}" Width="70"/>
                        <DataGridTextColumn Header="RAW / SCU" Binding="{Binding rawDisplay}" Width="130"/>
                        <DataGridTextColumn Header="REFINED / SCU" Binding="{Binding refinedDisplay}" Width="145"/>
                        <DataGridTextColumn Header="UPLIFT" Binding="{Binding uplift}" Width="90"/>
                        <DataGridTextColumn Header="RISK" Binding="{Binding risk}" Width="100"/>
                    </DataGrid.Columns>
                </DataGrid>
            </Grid>

            <!-- Run log -->
            <Grid x:Name="SettingsPage" Grid.Row="2" Visibility="Collapsed">
                <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="24" VerticalAlignment="Top">
                    <StackPanel>
                        <TextBlock Text="OVERLAY LETTERING" Foreground="#C7B5EF" FontSize="15" FontWeight="SemiBold"/>
                        <TextBlock x:Name="OverlayCoverage" Foreground="#AEA4BB" TextWrapping="Wrap" Margin="0,8,0,0"/>
                        <TextBlock Text="Adjust the size of the ore readout shown in game. Changes apply immediately; save to keep them for next time." Foreground="#AEA4BB" TextWrapping="Wrap" Margin="0,8,0,20"/>
                        <TextBlock x:Name="OverlayFontSizeLabel" Foreground="#FFB87A" Margin="0,0,0,8"/>
                        <Slider x:Name="OverlayFontSizeSlider" Minimum="-50" Maximum="50" Value="0" TickFrequency="10" SmallChange="10" LargeChange="10" IsSnapToTickEnabled="True" TickPlacement="BottomRight" Width="360" HorizontalAlignment="Left"/>
                        <Grid Width="360" HorizontalAlignment="Left" Margin="0,4,0,0">
                            <TextBlock Text="−50%" Foreground="#AEA4BB" HorizontalAlignment="Left"/>
                            <TextBlock Text="0% · Default" Foreground="#FFB87A" HorizontalAlignment="Center"/>
                            <TextBlock Text="+50%" Foreground="#AEA4BB" HorizontalAlignment="Right"/>
                        </Grid>
                        <Border Background="#09090D" CornerRadius="12" Padding="16" Margin="0,20,0,0">
                            <TextBlock x:Name="OverlayFontPreview" Text="Gold" Foreground="#FFB87A" FontSize="17" TextWrapping="Wrap"/>
                        </Border>
                        <Button x:Name="SaveSettings" Content="SAVE SETTINGS" HorizontalAlignment="Left" Margin="0,20,0,0"/>
                        <TextBlock x:Name="SettingsStatus" Text="F3 toggles the overlay while Star Citizen is active." Foreground="#AEA4BB" TextWrapping="Wrap" Margin="0,10,0,0"/>
                    </StackPanel>
                </Border>
            </Grid>
            <Grid x:Name="RunsPage" Grid.Row="2" Visibility="Collapsed">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="14"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Border Background="{StaticResource Panel}" BorderBrush="#C7B5EF" BorderThickness="0,4,0,0" CornerRadius="0" Padding="16">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="1.2*"/>
                            <ColumnDefinition Width="1.2*"/>
                            <ColumnDefinition Width=".8*"/>
                            <ColumnDefinition Width="170"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Margin="0,0,10,0">
                            <TextBlock Text="REFINERY" Foreground="#AEA4BB" FontSize="9"/>
                            <ComboBox x:Name="RunLocation" IsTextSearchEnabled="True" ToolTip="Choose a refinery" FontSize="11">
                                <ComboBox.ItemTemplate>
                                    <DataTemplate><TextBlock Text="{Binding}" TextWrapping="Wrap" MaxWidth="270"/></DataTemplate>
                                </ComboBox.ItemTemplate>
                            </ComboBox>
                        </StackPanel>
                        <StackPanel Grid.Column="1" Margin="0,0,10,0">
                            <TextBlock Text="ORE" Foreground="#AEA4BB" FontSize="9"/>
                            <ComboBox x:Name="RunOreSelect"/>
                        </StackPanel>
                        <StackPanel Grid.Column="2" Margin="0,0,10,0">
                            <TextBlock Text="SCU" Foreground="#AEA4BB" FontSize="9"/>
                            <TextBox x:Name="RunScu" Text="32"/>
                        </StackPanel>
                        <StackPanel Grid.Column="3" Margin="0,0,10,0">
                            <TextBlock Text="TIMER / HRS : MIN" Foreground="#AEA4BB" FontSize="9"/>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="6"/><ColumnDefinition/></Grid.ColumnDefinitions>
                                <ComboBox x:Name="RunHours" ToolTip="Hours"/>
                                <ComboBox x:Name="RunMinutes" Grid.Column="2" ToolTip="Minutes"/>
                            </Grid>
                        </StackPanel>
                        <Button x:Name="SaveRunButton" Grid.Column="4" Content="SAVE RUN" VerticalAlignment="Bottom" Background="#49334B" BorderBrush="#FFB87A"/>
                    </Grid>
                </Border>
                <DataGrid x:Name="RunGrid" Grid.Row="2" AlternationCount="2" SelectionMode="Single" SelectionUnit="FullRow">
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="DATE" Binding="{Binding date}" Width="150"/>
                        <DataGridTextColumn Header="LOCATION" Binding="{Binding location}" Width="*" MinWidth="200"/>
                        <DataGridTextColumn Header="ORE" Binding="{Binding ore}" Width="150"/>
                        <DataGridTextColumn Header="SCU" Binding="{Binding scu}" Width="90"/>
                        <DataGridTextColumn Header="TIMER" Binding="{Binding timerDisplay}" Width="150"/>
                    </DataGrid.Columns>
                </DataGrid>
                <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
                    <Button x:Name="DeleteCompletedJob" Content="DELETE SELECTED JOB" IsEnabled="False" FontSize="10" Margin="0,0,10,0" ToolTip="Select a row to delete that job, including jobs without timers"/>
                    <Button x:Name="DeleteAllCompletedJobs" Content="DELETE ALL COMPLETED" IsEnabled="False" FontSize="10" ToolTip="Deletes jobs whose timers have finished"/>
                </StackPanel>
            </Grid>
        </Grid>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$windowIconPath = Join-Path $PSScriptRoot 'ore-ops.ico'
if (-not (Test-Path -LiteralPath $windowIconPath)) { $windowIconPath = Join-Path $projectRoot 'launcher/ore-ops.ico' }
if (Test-Path -LiteralPath $windowIconPath) {
    $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([uri]$windowIconPath)
}

function Find-Control([string]$name) {
    return $window.FindName($name)
}

$pages = @{
    Dashboard = Find-Control "DashboardPage"
    Signature = Find-Control "SignaturePage"
    Scanner   = Find-Control "ScannerPage"
    Cargo     = Find-Control "CargoPage"
    Ores      = Find-Control "OresPage"
    Runs      = Find-Control "RunsPage"
    Settings  = Find-Control "SettingsPage"
}

function Show-Page([string]$name, [string]$title, [string]$subtitle) {
    foreach ($page in $pages.Values) { $page.Visibility = "Collapsed" }
    $pages[$name].Visibility = "Visible"
    foreach ($pageName in $pages.Keys) {
        (Find-Control "Nav$pageName").Tag = if ($pageName -eq $name) { "Active" } else { "" }
    }
    (Find-Control "PageTitle").Text = $title
    (Find-Control "PageSubtitle").Text = $subtitle
}

(Find-Control "NavDashboard").Add_Click({ Show-Page "Dashboard" "OPERATIONS DASHBOARD" "Plan the rock. Protect the ship. Maximize the haul." })
(Find-Control "NavSignature").Add_Click({ Show-Page "Signature" "SIGNATURE DECODER" "Turn an RS scan value into likely ore, rock type, and cluster size." })
(Find-Control "NavScanner").Add_Click({ Show-Page "Scanner" "ROCK ASSESSMENT" "Estimate whether a deposit fits your current mining setup." })
(Find-Control "NavCargo").Add_Click({ Show-Page "Cargo" "CARGO VALUE & TRADE" "Estimate mining value or rank live single-hop commodity routes." })
(Find-Control "NavOres").Add_Click({ Show-Page "Ores" "ORE INDEX" "Browse the locally cached patch-aware value guide." })
(Find-Control "NavRuns").Add_Click({ Show-Page "Runs" "RUN LOG" "Track refinery jobs, remaining time, and completed runs." })
(Find-Control "NavSettings").Add_Click({ Show-Page "Settings" "SETTINGS" "Customize your in-game overlay." })

$script:liveProfileVersion = [string]$data.patch
(Find-Control 'PatchLabel').Text = "STAR CITIZEN $($data.patch) LIVE"
(Find-Control 'PatchLabel').ToolTip = "$($data.liveBuild)`n$($data.liveVersionSource)"
(Find-Control 'UpdatedLabel').Text = "MINING DATA - $($data.verifiedAt)"
(Find-Control 'UpdatedLabel').ToolTip = "$($data.verificationStatus)`n$($data.verificationSource)"
(Find-Control 'LiveVersionStatus').Text = "LIVE version checked $($data.liveVersionCheckedAt)"

function Get-OfficialLiveBuild([string]$Html) {
    $match = [regex]::Match($Html, '(?i)\b(\d+\.\d+\.\d+)-LIVE\.(\d+)\b')
    if (-not $match.Success) { throw 'No released LIVE build found in the official patch notes.' }
    [pscustomobject]@{ version=$match.Groups[1].Value; build=($match.Groups[1].Value + '-LIVE.' + $match.Groups[2].Value) }
}
function Get-OfficialLiveVersionTitle([string]$Title) {
    $match=[regex]::Match($Title, '^Star Citizen Alpha (\d+\.\d+\.\d+) Known Issues$')
    if (-not $match.Success) { throw 'Unrecognized official LIVE known-issues title.' }
    $match.Groups[1].Value
}
$script:liveVersionDownload = $null
$script:liveVersionPending = $null
$liveVersionTimer = [Windows.Threading.DispatcherTimer]::new()
$liveVersionTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$liveVersionTimer.Add_Tick({
    if (-not $script:liveVersionPending.IsCompleted) { return }
    try {
        $result = @($script:liveVersionDownload.EndInvoke($script:liveVersionPending))[-1]
        if ($script:liveVersionDownload.HadErrors) { throw $script:liveVersionDownload.Streams.Error[0] }
        if ([version]$result.version -lt [version]$script:liveProfileVersion) { throw 'Official response is older than the known LIVE version.' }
        $script:liveProfileVersion = [string]$result.version
        (Find-Control 'PatchLabel').Text = "STAR CITIZEN $($result.version) LIVE"
        $buildLabel = if ($result.build) { [string]$result.build } elseif ($result.version -eq $data.patch) { "$($data.liveBuild) (bundled build reference)" } else { "LIVE $($result.version) (build number unavailable)" }
        (Find-Control 'PatchLabel').ToolTip = "$buildLabel`n$($result.source)"
        (Find-Control 'LiveVersionStatus').Text = "LIVE checked $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    } catch {
        (Find-Control 'LiveVersionStatus').Text = 'LIVE check unavailable; last known version shown.'
    } finally {
        $liveVersionTimer.Stop()
        $script:liveVersionDownload.Dispose(); $script:liveVersionDownload=$null; $script:liveVersionPending=$null
    }
})
function Start-LiveVersionCheck {
    if ($script:liveVersionPending) { return }
    (Find-Control 'LiveVersionStatus').Text = 'Checking official LIVE version...'
    $script:liveVersionDownload=[PowerShell]::Create()
    $null=$script:liveVersionDownload.AddScript('function Get-OfficialLiveBuild {' + ${function:Get-OfficialLiveBuild}.ToString() + '}')
    $null=$script:liveVersionDownload.AddScript('function Get-OfficialLiveVersionTitle {' + ${function:Get-OfficialLiveVersionTitle}.ToString() + '}')
    $null=$script:liveVersionDownload.AddScript({
        $ErrorActionPreference='Stop'
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        function Get-OfficialPage($Url) {
            $request=[Net.WebRequest]::Create($Url)
            $request.Timeout=10000; $request.ReadWriteTimeout=10000
            $response=$request.GetResponse()
            $reader=[IO.StreamReader]::new($response.GetResponseStream())
            try { $reader.ReadToEnd() } finally { $reader.Dispose(); $response.Dispose() }
        }
        # RSI's current known-issues article is machine readable, unlike the
        # release page body which may require JavaScript to render.
        try {
            $article=(Get-OfficialPage 'https://support.robertsspaceindustries.com/api/v2/help_center/en-us/articles/360056254754.json' | ConvertFrom-Json).article
            $version=Get-OfficialLiveVersionTitle ([string]$article.title)
            [pscustomobject]@{ version=$version; build=''; source=[string]$article.html_url }
            return
        } catch { }
        $listing=Get-OfficialPage 'https://robertsspaceindustries.com/en/development'
        $links=@([regex]::Matches($listing, '(?i)/(?:en/)?comm-link/Patch-Notes/\d+[^"''<>\s]*') | ForEach-Object { $_.Value } | Select-Object -Unique -First 3)
        foreach ($link in $links) {
            $url='https://robertsspaceindustries.com' + $link
            try {
                $html=Get-OfficialPage $url
                $build=Get-OfficialLiveBuild $html
                $build | Add-Member -NotePropertyName source -NotePropertyValue $url
                $build
                return
            } catch { continue }
        }
        throw 'No confirmed LIVE release could be retrieved.'
    }.ToString())
    $script:liveVersionPending=$script:liveVersionDownload.BeginInvoke()
    $liveVersionTimer.Start()
}
$window.Add_Closed({
    $liveVersionTimer.Stop()
    if ($script:liveVersionDownload) { $script:liveVersionDownload.Stop(); $script:liveVersionDownload.Dispose() }
})

function Update-RefineryDashboard {
    foreach ($refinery in $data.refineries) {
        $prefix = [string]$refinery.system
        (Find-Control "${prefix}RefineryName").Text = [string]$refinery.name
        (Find-Control "${prefix}RefineryRating").Text = [string]$refinery.rating
        (Find-Control "${prefix}RefineryHighlight").Text = [string]$refinery.highlight
        (Find-Control "${prefix}RefineryNote").Text = [string]$refinery.note
    }
}

Update-RefineryDashboard

$snapshotUrl = "https://raw.githubusercontent.com/quattrobaje3na-png/SC-Mining-Material-Finder-2.0/main/mining_compiled.json"
(Find-Control "SnapshotButton").Add_Click({
    Start-LiveVersionCheck
    $button = Find-Control "SnapshotButton"
    $status = Find-Control "SnapshotStatus"
    $button.IsEnabled = $false
    $button.Content = "DOWNLOADING..."
    $status.Text = "Contacting data source"
    $status.Foreground = "#F6C85F"

    try {
        $hadOldSnapshot = Test-Path -LiteralPath $locationDataPath
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object Net.WebClient
        $snapshotText = $webClient.DownloadString($snapshotUrl)
        $newSnapshot = $snapshotText | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace([string]$newSnapshot.version) -or @($newSnapshot.locations).Count -eq 0) {
            throw "The downloaded file did not contain a valid mining location snapshot."
        }

        $temporaryPath = "$locationDataPath.download"
        $utf8WithoutBom = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($temporaryPath, $snapshotText, $utf8WithoutBom)
        Move-Item -LiteralPath $temporaryPath -Destination $locationDataPath -Force
        Get-ChildItem -LiteralPath (Split-Path -Parent $locationDataPath) -Filter "mining-compiled-*.json" -File |
            Where-Object { $_.FullName -ne $locationDataPath } |
            Remove-Item -Force
        $script:locationData = $newSnapshot

        (Find-Control "UpdatedLabel").Text = "MINING DATA - $($data.verifiedAt)"
        $snapshotAction = if ($hadOldSnapshot) { "Replaced" } else { "Saved" }
        $status.Text = "Complete - $(@($newSnapshot.locations).Count) locations"
        $status.ToolTip = "$snapshotAction dataset $($newSnapshot.version) at $(Get-Date -Format 'HH:mm')"
        $status.Foreground = "#5EE6A8"
        (Find-Control "DecodeSignatureButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        $button.Content = "COMPLETE"
    } catch {
        $button.Content = "DOWNLOAD SNAPSHOT"
        $status.Text = "Download failed"
        $status.ToolTip = $null
        $status.Foreground = "#ED6A5A"
        [System.Windows.MessageBox]::Show(
            "The mining snapshot could not be downloaded.`n`n$($_.Exception.Message)",
            "Snapshot download",
            "OK",
            "Warning") | Out-Null
    } finally {
        if ($null -ne $webClient) { $webClient.Dispose() }
        if (Test-Path -LiteralPath "$locationDataPath.download") {
            Remove-Item -LiteralPath "$locationDataPath.download" -Force
        }
        $button.IsEnabled = $true
    }
})

function Get-TopOreBuyers($Ores, $Prices) {
    $rows = foreach ($ore in $Ores) {
        $buyer = @($Prices | Where-Object {
            ($_.commodity_name -eq $ore.name -or ($ore.name -eq 'Quantanium' -and $_.commodity_name -eq 'Quantainium')) -and [double]$_.price_sell -gt 0
        } | Sort-Object @{Expression={ [double]$_.price_sell };Descending=$true}, terminal_name | Select-Object -First 1)
        if ($buyer.Count -gt 0) {
            [pscustomobject]@{ ore=$ore.name; price=[double]$buyer[0].price_sell; priceDisplay=('{0:N0}' -f [double]$buyer[0].price_sell); buyer=[string]$buyer[0].terminal_name }
        }
    }
    @($rows | Sort-Object @{Expression={ $_.price };Descending=$true}, ore | Select-Object -First 4)
}
$buyerSnapshotPath = Join-Path $projectRoot 'data/ore-buyers.json'
if (Test-Path -LiteralPath $buyerSnapshotPath) {
    $buyerSnapshot = Get-Content -Raw -LiteralPath $buyerSnapshotPath | ConvertFrom-Json
    (Find-Control 'TopOreBuyers').ItemsSource = @(Get-TopOreBuyers $data.ores $buyerSnapshot.prices)
    (Find-Control 'OreBuyerStatus').Text = "UEX snapshot: $($buyerSnapshot.checkedAt)"
} else {
    (Find-Control 'OreBuyerStatus').Text = 'Refresh to load best reported buying locations.'
}
$script:buyerDownload = $null
$script:buyerPending = $null
$buyerTimer = [System.Windows.Threading.DispatcherTimer]::new()
$buyerTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$buyerTimer.Add_Tick({
    if (-not $script:buyerPending.IsCompleted) { return }
    try {
        $json = [string]($script:buyerDownload.EndInvoke($script:buyerPending) | Select-Object -Last 1)
        if ($script:buyerDownload.HadErrors) { throw $script:buyerDownload.Streams.Error[0] }
        $response = $json | ConvertFrom-Json
        if ($response.status -ne 'ok' -or @($response.data).Count -eq 0) { throw 'Empty market response' }
        $rows = @(Get-TopOreBuyers $data.ores $response.data)
        if ($rows.Count -lt 4) { throw 'Not enough refined ore buyer prices returned' }
        (Find-Control 'TopOreBuyers').ItemsSource = $rows
        (Find-Control 'OreBuyerStatus').Text = "UEX refreshed $(Get-Date -Format 'yyyy-MM-dd HH:mm') | best reported buyers"
    } catch {
        (Find-Control 'OreBuyerStatus').Text = 'Refresh failed. Previous prices retained.'
    } finally {
        $buyerTimer.Stop()
        $script:buyerDownload.Dispose(); $script:buyerDownload=$null; $script:buyerPending=$null
        (Find-Control 'RefreshOreBuyers').IsEnabled = $true
    }
})
(Find-Control 'RefreshOreBuyers').Add_Click({
    if ($script:buyerPending) { return }
    (Find-Control 'RefreshOreBuyers').IsEnabled = $false
    (Find-Control 'OreBuyerStatus').Text = 'Downloading buyer prices...'
    $script:buyerDownload = [PowerShell]::Create()
    $null = $script:buyerDownload.AddScript({
        $ErrorActionPreference='Stop'
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        $request=[Net.WebRequest]::Create('https://api.uexcorp.uk/2.0/commodities_prices_all')
        $request.Timeout=15000; $request.ReadWriteTimeout=15000
        $response=$request.GetResponse()
        $reader=[IO.StreamReader]::new($response.GetResponseStream())
        try { $reader.ReadToEnd() } finally { $reader.Dispose(); $response.Dispose() }
    }.ToString())
    $script:buyerPending=$script:buyerDownload.BeginInvoke()
    $buyerTimer.Start()
})
$window.Add_Closed({
    $buyerTimer.Stop()
    if ($script:buyerDownload) { $script:buyerDownload.Stop(); $script:buyerDownload.Dispose() }
})

$oreRows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
foreach ($ore in $data.ores) {
    $oreRows.Add([pscustomobject]@{
        name = $ore.name
        code = $ore.code
        tier = $ore.tier
        raw = [double]$ore.raw
        refined = [double]$ore.refined
        rawDisplay = "{0:N0}" -f $ore.raw
        refinedDisplay = "{0:N0}" -f $ore.refined
        uplift = if ($ore.raw -gt 0) { "{0:N1}x" -f ($ore.refined / $ore.raw) } else { "-" }
        risk = $ore.risk
    })
}
(Find-Control "OreGrid").ItemsSource = $oreRows

$oreNames = @($data.ores | ForEach-Object { $_.name })
$shipNames = @($data.ships | ForEach-Object { $_.name })
$shipTradeMinerals = if ($null -ne $locationData -and @($locationData.materials).Count -gt 0) {
    @($locationData.materials | Sort-Object -Unique)
} else {
    @($data.ores | ForEach-Object { $_.name } | Sort-Object -Unique)
}
$vehicleTradeMinerals = @("Beradom", "Feynmaline", "Glacosite")
$handTradeMinerals = @("Aphorite", "Dolivine", "Hadanite", "Janalite")
$tradeMineralOptions = @("ALL MINERALS") + @($shipTradeMinerals + $vehicleTradeMinerals + $handTradeMinerals | Sort-Object -Unique)
$script:uexPriceRows = @()
$script:uexPriceSource = ""
$script:uexTerminalRows = @()
$script:uexTerminalSystemById = @{}
$script:uexTerminalById = @{}
$tradeSystemOptions = @("ALL SYSTEMS", "Stanton", "Pyro", "Nyx")
(Find-Control "TradeCategorySelect").ItemsSource = @("MINERALS", "COMMODITIES")
(Find-Control "TradeCategorySelect").SelectedIndex = 0
(Find-Control "TradeItemSelect").ItemsSource = $tradeMineralOptions
(Find-Control "TradeItemSelect").SelectedIndex = 0
(Find-Control "TradeSystemSelect").ItemsSource = $tradeSystemOptions
(Find-Control "TradeSystemSelect").SelectedIndex = 0
$tradeShipCapacityByDisplay = @{}
$tradeShipOptions = @()
foreach ($ship in @($tradeShipData.ships | Sort-Object name)) {
    $display = [string]$ship.name
    $tradeShipOptions += $display
    $tradeShipCapacityByDisplay[$display] = [double]$ship.scu
}
(Find-Control "TradeShipSelect").ItemsSource = $tradeShipOptions
(Find-Control "TradeShipSelect").Add_SelectionChanged({
    $selectedShip = [string](Find-Control "TradeShipSelect").SelectedItem
    if ($tradeShipCapacityByDisplay.ContainsKey($selectedShip)) {
        (Find-Control "TradeCargoScu").Text = "{0:0.##}" -f [double]$tradeShipCapacityByDisplay[$selectedShip]
    }
    if ($script:uexPriceRows.Count -gt 0) {
        (Find-Control "FindTradeRoutesButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    }
})
$defaultTradeShip = @($tradeShipOptions | Where-Object { $_ -eq "Crusader C1 Spirit" } | Select-Object -First 1)
(Find-Control "TradeShipSelect").SelectedItem = if ($defaultTradeShip.Count -gt 0) { $defaultTradeShip[0] } else { $tradeShipOptions[0] }
foreach ($name in @("CargoOreSelect", "RunOreSelect")) {
    (Find-Control $name).ItemsSource = $oreNames
    (Find-Control $name).SelectedIndex = 0
}

$moduleNames = @("EMPTY SLOT") + @($data.miningModules | ForEach-Object { "$($_.name) [$($_.type)]" })
$gadgetNames = @($data.gadgets | ForEach-Object { $_.name })
$script:compatibleHeads = @()
$script:activeHeadCount = 1
$script:headEnabled = @($true, $true, $true)
$script:assessmentReady = $false

function Get-SelectedMiningModule([string]$controlName) {
    $selectedIndex = (Find-Control $controlName).SelectedIndex
    if ($selectedIndex -le 0) { return $null }
    return $data.miningModules[$selectedIndex - 1]
}

function Get-HeadLoadout([int]$position) {
    $shipIndex = (Find-Control "ShipSelect").SelectedIndex
    $headIndex = (Find-Control "Head${position}Select").SelectedIndex
    if ($shipIndex -lt 0 -or $headIndex -lt 0 -or $script:compatibleHeads.Count -eq 0) { return $null }

    $ship = $data.ships[$shipIndex]
    $head = $script:compatibleHeads[$headIndex]
    [double]$powerMultiplier = [double]$head.powerFactor
    [double]$resistanceModifier = [double]$head.resistance
    [double]$instabilityModifier = [double]$head.instability
    [double]$windowModifier = [double]$head.window
    [double]$filterRating = [double]$head.filter
    [double]$laserOutput = [double]$head.laserPower
    [double]$extractionOutput = [double]$head.extraction
    $selectedModules = @()
    $activeModules = @()

    for ($slot = 1; $slot -le [int]$head.slots; $slot++) {
        $controlName = "Head${position}Module${slot}"
        $module = Get-SelectedMiningModule $controlName
        if ($null -ne $module) {
            $powerMultiplier *= ([double]$module.power / 100.0)
            $resistanceModifier += [double]$module.resistance
            $instabilityModifier += [double]$module.instability
            $windowModifier += [double]$module.window
            $filterRating += [double]$module.filter
            $laserOutput *= ([double]$module.power / 100.0)
            $extractionMultiplier = if ($null -ne $module.PSObject.Properties["extraction"]) { [double]$module.extraction } else { 100.0 }
            $extractionOutput *= ($extractionMultiplier / 100.0)
            $selectedModules += [string]$module.name
            if ($module.type -eq "Active") { $activeModules += [string]$module.name }
        }
    }

    return [pscustomobject]@{
        head = $head
        power = ([double]$ship.power * $powerMultiplier)
        resistance = $resistanceModifier
        instability = $instabilityModifier
        window = $windowModifier
        filter = $filterRating
        laserOutput = $laserOutput
        extraction = $extractionOutput
        rangeMin = [double]$head.rangeMin
        rangeMax = [double]$head.rangeMax
        modules = $selectedModules
        activeModules = $activeModules
    }
}

function Get-CurrentLoadout {
    $shipIndex = (Find-Control "ShipSelect").SelectedIndex
    if ($shipIndex -lt 0) { return $null }

    $headLoadouts = @()
    for ($position = 1; $position -le $script:activeHeadCount; $position++) {
        if (-not $script:headEnabled[$position - 1]) { continue }
        $headLoadout = Get-HeadLoadout $position
        if ($null -eq $headLoadout) { return $null }
        $headLoadouts += $headLoadout
    }
    if ($headLoadouts.Count -eq 0) { return $null }

    $gadgetIndex = (Find-Control "GadgetSelect").SelectedIndex
    if ($gadgetIndex -lt 0) { $gadgetIndex = 0 }
    $gadget = $data.gadgets[$gadgetIndex]

    return [pscustomobject]@{
        ship = $data.ships[$shipIndex]
        heads = $headLoadouts
        gadget = $gadget
        power = [double](($headLoadouts | Measure-Object -Property power -Sum).Sum)
        laserOutput = [double](($headLoadouts | Measure-Object -Property laserOutput -Sum).Sum)
        extraction = [double](($headLoadouts | Measure-Object -Property extraction -Sum).Sum)
        rangeMin = [double](($headLoadouts | Measure-Object -Property rangeMin -Minimum).Minimum)
        rangeMax = [double](($headLoadouts | Measure-Object -Property rangeMax -Maximum).Maximum)
        resistance = [double](($headLoadouts | Measure-Object -Property resistance -Average).Average) + [double]$gadget.resistance
        instability = [double](($headLoadouts | Measure-Object -Property instability -Average).Average) + [double]$gadget.instability
        window = [double](($headLoadouts | Measure-Object -Property window -Average).Average) + [double]$gadget.window
        filter = [double](($headLoadouts | Measure-Object -Property filter -Average).Average) + [double]$gadget.filter
        modules = @($headLoadouts | ForEach-Object { $_.modules } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        activeModules = @($headLoadouts | ForEach-Object { $_.activeModules } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
}

function Set-CenteredMetric([string]$prefix, [string]$valueName, [double]$value, [bool]$lowerIsBetter) {
    $beneficialColor = "#5EE6A8"
    $harmfulColor = "#ED6A5A"
    $negativeColor = if ($lowerIsBetter) { $beneficialColor } else { $harmfulColor }
    $positiveColor = if ($lowerIsBetter) { $harmfulColor } else { $beneficialColor }
    $color = if ($value -lt 0) {
        $negativeColor
    } elseif ($value -gt 0) {
        $positiveColor
    } else {
        "#AEA4BB"
    }
    $negativeBar = Find-Control "${prefix}Negative"
    $positiveBar = Find-Control "${prefix}Positive"
    $negativeBar.Background = $negativeColor
    $positiveBar.Background = $positiveColor
    $negativeBar.Width = if ($value -lt 0) { [Math]::Min(100, [Math]::Abs($value)) } else { 0 }
    $positiveBar.Width = if ($value -gt 0) { [Math]::Min(100, $value) } else { 0 }
    (Find-Control $valueName).Foreground = $color
}

function Update-AssessmentGraph {
    $loadout = Get-CurrentLoadout
    if ($null -eq $loadout) {
        foreach ($prefix in @("Instability", "Window", "Resistance", "Filter")) {
            (Find-Control "${prefix}Negative").Width = 0
            (Find-Control "${prefix}Positive").Width = 0
            (Find-Control "${prefix}GraphValue").Text = "0%"
            (Find-Control "${prefix}GraphValue").Foreground = "#AEA4BB"
        }
        return
    }

    $instabilityModifier = [Math]::Max(-100, [Math]::Min(100, [double]$loadout.instability))
    $resistanceModifier = [Math]::Max(-100, [Math]::Min(100, [double]$loadout.resistance))
    $windowModifier = [Math]::Max(-100, [Math]::Min(100, [double]$loadout.window))
    $filterRating = [Math]::Max(-100, [Math]::Min(100, [double]$loadout.filter))

    (Find-Control "InstabilityGraphValue").Text = "{0:+0;-0;0}%" -f $instabilityModifier
    (Find-Control "WindowGraphValue").Text = "{0:+0;-0;0}%" -f $windowModifier
    (Find-Control "ResistanceGraphValue").Text = "{0:+0;-0;0}%" -f $resistanceModifier
    (Find-Control "FilterGraphValue").Text = "{0:+0.#;-0.#;0}%" -f $filterRating

    Set-CenteredMetric "Instability" "InstabilityGraphValue" $instabilityModifier $true
    Set-CenteredMetric "Window" "WindowGraphValue" $windowModifier $false
    Set-CenteredMetric "Resistance" "ResistanceGraphValue" $resistanceModifier $true
    Set-CenteredMetric "Filter" "FilterGraphValue" $filterRating $false
}

function Update-LoadoutStats {
    $loadout = Get-CurrentLoadout
    if ($null -eq $loadout) {
        (Find-Control "LoadoutStats").Text = "No mining heads active. Activate at least one head to assess the deposit."
        (Find-Control "EffectiveDps").Text = "0 EFF. DPS"
        (Find-Control "ExtractionStats").Text = "Extraction: 0 DPS | Range: -"
        (Find-Control "GadgetBenefit").Text = "Gadget modifiers apply when a mining head is active."
        Update-AssessmentGraph
        if ($script:assessmentReady) {
            (Find-Control "AssessmentStatus").Text = "NO ACTIVE HEADS"
            (Find-Control "AssessmentStatus").Foreground = "#F6C85F"
            (Find-Control "AssessmentScore").Text = "Activate at least one mining head to continue."
            (Find-Control "AssessmentDetail").Text = "Inactive mining heads and their attached modules are excluded from the assessment."
        }
        return
    }
    $moduleText = if ($loadout.modules.Count -gt 0) { $loadout.modules -join " + " } else { "No modules" }
    $headText = @($loadout.heads | ForEach-Object { $_.head.name }) -join " + "
    (Find-Control "LoadoutStats").Text = "{0} | {1} | total power {2:N2}x | {3}" -f $loadout.ship.name, $headText, $loadout.power, $moduleText
    (Find-Control "EffectiveDps").Text = "{0:N0} EFF. DPS" -f $loadout.laserOutput
    (Find-Control "ExtractionStats").Text = "Extraction: {0:N0} DPS | Range: {1:N0}-{2:N0}m" -f $loadout.extraction, $loadout.rangeMin, $loadout.rangeMax
    (Find-Control "GadgetBenefit").Text = "Gadget: $($loadout.gadget.benefit)"
    Update-AssessmentGraph
    if ($script:assessmentReady) {
        (Find-Control "AssessButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    }
}

function Update-HeadActivationUi([int]$position) {
    $isActive = $position -le $script:activeHeadCount -and $script:headEnabled[$position - 1]
    $toggle = Find-Control "Head${position}Toggle"
    $toggle.Content = if ($isActive) { "ACTIVE" } else { "INACTIVE" }
    $toggle.Background = if ($isActive) { "#49334B" } else { "#211820" }
    $toggle.BorderBrush = if ($isActive) { "#FFB87A" } else { "#7A4650" }
    $toggle.Foreground = if ($isActive) { "#C7B5EF" } else { "#D98B96" }
    (Find-Control "Head${position}Select").IsEnabled = $isActive
    (Find-Control "Head${position}Select").Opacity = if ($isActive) { 1.0 } else { 0.45 }
    (Find-Control "ModuleLabel${position}").Opacity = if ($isActive) { 1.0 } else { 0.45 }
    (Find-Control "ModuleGrid${position}").IsEnabled = $isActive
    (Find-Control "ModuleGrid${position}").Opacity = if ($isActive) { 1.0 } else { 0.45 }
    (Find-Control "Loadout${position}Panel").BorderBrush = if ($isActive) { "#4C405D" } else { "#4A3038" }
}

function Toggle-MiningHead([int]$position) {
    if ($position -gt $script:activeHeadCount) { return }
    $script:headEnabled[$position - 1] = -not $script:headEnabled[$position - 1]
    Update-HeadActivationUi $position
    Update-LoadoutStats
}

function Update-ModuleSlots([int]$position) {
    $headIndex = (Find-Control "Head${position}Select").SelectedIndex
    if ($headIndex -lt 0 -or $script:compatibleHeads.Count -eq 0) { return }
    $slotCount = [int]$script:compatibleHeads[$headIndex].slots
    $moduleGrid = Find-Control "ModuleGrid${position}"
    $moduleLabel = Find-Control "ModuleLabel${position}"
    $moduleGrid.Columns = [Math]::Max(1, $slotCount)
    $moduleGrid.Visibility = if ($slotCount -gt 0) { "Visible" } else { "Collapsed" }
    $moduleLabel.Visibility = if ($slotCount -gt 0) { "Visible" } else { "Collapsed" }

    for ($slot = 1; $slot -le 3; $slot++) {
        $control = Find-Control "Head${position}Module${slot}"
        $control.ItemsSource = $moduleNames
        $control.SelectedIndex = 0
        $control.Visibility = if ($slot -le $slotCount) { "Visible" } else { "Collapsed" }
    }
    Update-LoadoutStats
}

function Update-CompatibleHeads {
    $shipIndex = (Find-Control "ShipSelect").SelectedIndex
    if ($shipIndex -lt 0) { return }
    $ship = $data.ships[$shipIndex]
    $headSize = [int]$ship.headSize
    $script:activeHeadCount = [int]$ship.laserCount
    $script:headEnabled = @($true, $true, $true)
    $script:compatibleHeads = @($data.miningHeads | Where-Object { [int]$_.size -eq $headSize })

    (Find-Control "Head1Label").Text = if ($script:activeHeadCount -eq 3) { "CENTER MINING HEAD" } else { "MINING HEAD" }
    for ($position = 1; $position -le 3; $position++) {
        $panel = Find-Control "Loadout${position}Panel"
        $panel.Visibility = if ($position -le $script:activeHeadCount) { "Visible" } else { "Collapsed" }
        $headControl = Find-Control "Head${position}Select"
        $headControl.ItemsSource = @($script:compatibleHeads | ForEach-Object { "$($_.name) (S$($_.size))" })
        $headControl.SelectedIndex = 0
        Update-ModuleSlots $position
        Update-HeadActivationUi $position
    }
}

(Find-Control "GadgetSelect").ItemsSource = $gadgetNames
(Find-Control "GadgetSelect").Add_SelectionChanged({ Update-LoadoutStats })
(Find-Control "GadgetSelect").SelectedIndex = 0
(Find-Control "ShipSelect").ItemsSource = $shipNames
(Find-Control "ShipSelect").Add_SelectionChanged({ Update-CompatibleHeads })
(Find-Control "Head1Select").Add_SelectionChanged({ Update-ModuleSlots 1 })
(Find-Control "Head2Select").Add_SelectionChanged({ Update-ModuleSlots 2 })
(Find-Control "Head3Select").Add_SelectionChanged({ Update-ModuleSlots 3 })
(Find-Control "Head1Toggle").Add_Click({ Toggle-MiningHead 1 })
(Find-Control "Head2Toggle").Add_Click({ Toggle-MiningHead 2 })
(Find-Control "Head3Toggle").Add_Click({ Toggle-MiningHead 3 })
foreach ($controlName in @(
    "Head1Module1", "Head1Module2", "Head1Module3",
    "Head2Module1", "Head2Module2", "Head2Module3",
    "Head3Module1", "Head3Module2", "Head3Module3")) {
    (Find-Control $controlName).Add_SelectionChanged({ Update-LoadoutStats })
}
(Find-Control "Resistance").Add_TextChanged({ Update-AssessmentGraph })
(Find-Control "Instability").Add_TextChanged({ Update-AssessmentGraph })
(Find-Control "ShipSelect").SelectedIndex = 0

$fitPresetPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "OreOps\ship-presets.json"
$script:fitPresets = @()
function Get-FitPreset([string]$name) {
    $ship = [string](Find-Control "ShipSelect").SelectedItem
    $heads = @(for ($position = 1; $position -le $script:activeHeadCount; $position++) {
        [pscustomobject]@{
            head = [string](Find-Control "Head${position}Select").SelectedItem
            enabled = [bool]$script:headEnabled[$position - 1]
            modules = @(for ($slot = 1; $slot -le 3; $slot++) { [string](Find-Control "Head${position}Module${slot}").SelectedItem })
        }
    })
    [pscustomobject]@{ name=$name; ship=$ship; label="$ship / $name"; heads=$heads; gadget=[string](Find-Control "GadgetSelect").SelectedItem }
}
function Write-FitPresets($items) {
    $folder = Split-Path -Parent $fitPresetPath
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $json = ConvertTo-Json -InputObject @($items) -Depth 8
    [IO.File]::WriteAllText("$fitPresetPath.tmp", $json)
    Move-Item -LiteralPath "$fitPresetPath.tmp" -Destination $fitPresetPath -Force
    $script:fitPresets = @($items)
    (Find-Control "FitPresetSelect").ItemsSource = $script:fitPresets
}
function Set-FitPreset($preset) {
    $ship = @($data.ships | Where-Object { $_.name -eq $preset.ship })
    if ($ship.Count -ne 1 -or $preset.heads.Count -ne [int]$ship[0].laserCount -or $gadgetNames -notcontains $preset.gadget) {
        throw "This preset does not match the current ship or gadget data."
    }
    $validHeads = @($data.miningHeads | Where-Object { [int]$_.size -eq [int]$ship[0].headSize } | ForEach-Object { "$($_.name) (S$($_.size))" })
    foreach ($head in $preset.heads) {
        if ($validHeads -notcontains $head.head -or $head.modules.Count -ne 3) { throw "This preset contains an unavailable mining head." }
        foreach ($module in $head.modules) { if ($moduleNames -notcontains $module) { throw "This preset contains an unavailable module." } }
    }
    (Find-Control "ShipSelect").SelectedItem = $preset.ship
    Update-CompatibleHeads
    for ($position = 1; $position -le $preset.heads.Count; $position++) {
        $head = $preset.heads[$position - 1]
        (Find-Control "Head${position}Select").SelectedItem = $head.head
        for ($slot = 1; $slot -le 3; $slot++) {
            (Find-Control "Head${position}Module${slot}").SelectedItem = $head.modules[$slot - 1]
        }
        $script:headEnabled[$position - 1] = [bool]$head.enabled
        Update-HeadActivationUi $position
    }
    (Find-Control "GadgetSelect").SelectedItem = $preset.gadget
    Update-LoadoutStats
}
(Find-Control "FitPresetSelect").Add_SelectionChanged({
    $preset = (Find-Control "FitPresetSelect").SelectedItem
    (Find-Control "LoadFitPreset").IsEnabled = $null -ne $preset
    (Find-Control "DeleteFitPreset").IsEnabled = $null -ne $preset
    if ($null -ne $preset) { (Find-Control "FitPresetName").Text = $preset.name }
})
if (Test-Path -LiteralPath $fitPresetPath) {
    try {
        $storedFits = Get-Content -Raw -LiteralPath $fitPresetPath | ConvertFrom-Json
        $script:fitPresets = @($storedFits | Where-Object { $null -ne $_ })
        (Find-Control "FitPresetSelect").ItemsSource = $script:fitPresets
    } catch {
        (Find-Control "FitPresetStatus").Text = "Saved presets could not be read. Your file has been kept."
        (Find-Control "SaveFitPreset").IsEnabled = $false
    }
}
(Find-Control "SaveFitPreset").Add_Click({
    $name = (Find-Control "FitPresetName").Text.Trim()
    if (-not $name) { (Find-Control "FitPresetStatus").Text = "Enter a name for your preset first."; return }
    try {
        $preset = Get-FitPreset $name
        $items = @($script:fitPresets | Where-Object { -not ($_.name -eq $name -and $_.ship -eq $preset.ship) }) + @($preset)
        Write-FitPresets $items
        (Find-Control "FitPresetSelect").SelectedItem = $preset
        (Find-Control "FitPresetStatus").Text = "Saved: $($preset.label)"
    } catch { (Find-Control "FitPresetStatus").Text = "Could not save the preset. Please try again." }
})
(Find-Control "LoadFitPreset").Add_Click({
    $preset = (Find-Control "FitPresetSelect").SelectedItem
    if ($null -eq $preset) { return }
    try {
        Set-FitPreset $preset
        (Find-Control "FitPresetStatus").Text = "Loaded: $($preset.label)"
    } catch { (Find-Control "FitPresetStatus").Text = $_.Exception.Message }
})
(Find-Control "DeleteFitPreset").Add_Click({
    $preset = (Find-Control "FitPresetSelect").SelectedItem
    if ($null -eq $preset) { return }
    try {
        Write-FitPresets @($script:fitPresets | Where-Object { -not ($_.name -eq $preset.name -and $_.ship -eq $preset.ship) })
        (Find-Control "FitPresetName").Text = ""
        (Find-Control "FitPresetStatus").Text = "Preset deleted."
    } catch { (Find-Control "FitPresetStatus").Text = "Could not delete the preset. Please try again." }
})

(Find-Control "OreSearch").Add_TextChanged({
    $term = (Find-Control "OreSearch").Text.Trim()
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView((Find-Control "OreGrid").ItemsSource)
    if ([string]::IsNullOrWhiteSpace($term)) {
        $view.Filter = $null
    } else {
        $view.Filter = [Predicate[object]]{
            param($row)
            return $row.name.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                   $row.code.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0
        }
    }
    $view.Refresh()
})

function Try-Number([string]$text, [ref]$value) {
    return [double]::TryParse($text, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, $value)
}

$signatureRows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
(Find-Control "SignatureGrid").ItemsSource = $signatureRows
$locationRows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
(Find-Control "LocationGrid").ItemsSource = $locationRows
$script:currentLocations = @()

function Update-LocationsForMineral {
    $selectedMineral = [string](Find-Control "MineralFilter").SelectedItem
    $selectedMethod = [string](Find-Control "MiningMethodFilter").SelectedItem
    $methodKeys = switch ($selectedMethod) {
        "VEHICLE / ROC" { @("ROC") }
        "HAND MINING" { @("Hand", "FPS") }
        default { @("Ship") }
    }
    $foundLocations = @()
    if (-not [string]::IsNullOrWhiteSpace($selectedMineral) -and $null -ne $locationData) {
        foreach ($location in $locationData.locations) {
            foreach ($methodKey in $methodKeys) {
                foreach ($material in @($location.methods.$methodKey)) {
                    if ($material.name -eq $selectedMineral) {
                        $methodLabel = if ($selectedMethod -eq "VEHICLE / ROC") { "Vehicle" } elseif ($selectedMethod -eq "HAND MINING") { "Hand" } else { "Ship" }
                        $foundLocations += [pscustomobject]@{
                            system = [string]$location.system
                            location = [string]$location.name
                            chance = [double]$material.chance
                            chanceDisplay = "{0:N1}%" -f [double]$material.chance
                            method = $methodLabel
                        }
                        break
                    }
                }
            }
        }
    }
    if ($foundLocations.Count -eq 0 -and $selectedMethod -ne "SHIP MINING" -and $null -ne $groundLocationData) {
        $fallbackMethod = if ($selectedMethod -eq "VEHICLE / ROC") { "Vehicle" } else { "Hand" }
        foreach ($group in @($groundLocationData.groups | Where-Object { $_.mineral -eq $selectedMineral -and $_.method -eq $fallbackMethod })) {
            foreach ($locationName in @($group.locations)) {
                $foundLocations += [pscustomobject]@{
                    system = [string]$group.system
                    location = [string]$locationName
                    chance = [double]$group.chance
                    chanceDisplay = "{0:N1}%" -f [double]$group.chance
                    method = $fallbackMethod
                }
            }
        }
    }
    $script:currentLocations = @($foundLocations | Sort-Object @{ Expression = "chance"; Descending = $true }, system, location)
    Refresh-LocationGrid
}

function Refresh-LocationGrid {
    $locationRows.Clear()
    $selectedSystem = [string](Find-Control "SystemFilter").SelectedItem
    $filteredLocations = if ([string]::IsNullOrWhiteSpace($selectedSystem) -or $selectedSystem -eq "All Systems") {
        @($script:currentLocations)
    } else {
        @($script:currentLocations | Where-Object { $_.system -eq $selectedSystem })
    }
    foreach ($location in $filteredLocations) {
        $locationRows.Add($location)
    }
    (Find-Control "LocationEmptyState").Visibility = if ($locationRows.Count -eq 0) { "Visible" } else { "Collapsed" }
}

(Find-Control "SystemFilter").ItemsSource = @("All Systems", "Stanton", "Pyro", "Nyx")
(Find-Control "SystemFilter").SelectedIndex = 0
(Find-Control "SystemFilter").Add_SelectionChanged({ Refresh-LocationGrid })

function Update-MineralOptions {
    $method = [string](Find-Control "MiningMethodFilter").SelectedItem
    $snapshotMethodKeys = switch ($method) {
        "VEHICLE / ROC" { @("ROC") }
        "HAND MINING" { @("Hand", "FPS") }
        default { @("Ship") }
    }
    $fallbackMinerals = switch ($method) {
        "VEHICLE / ROC" { @("Beradom", "Feynmaline", "Glacosite") }
        "HAND MINING" { @("Aphorite", "Dolivine", "Hadanite", "Janalite") }
        default { @() }
    }
    $snapshotMinerals = @()
    if ($null -ne $locationData) {
        foreach ($methodKey in $snapshotMethodKeys) {
            $snapshotMinerals += @($locationData.locations | ForEach-Object { @($_.methods.$methodKey) } | ForEach-Object { $_.name })
        }
    }
    $minerals = @($snapshotMinerals + $fallbackMinerals | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    (Find-Control "MineralFilter").ItemsSource = $minerals
    (Find-Control "MineralFilter").SelectedIndex = if ($minerals.Count -gt 0) { 0 } else { -1 }
    Update-LocationsForMineral
}

(Find-Control "MineralFilter").Add_SelectionChanged({ Update-LocationsForMineral })
(Find-Control "MiningMethodFilter").ItemsSource = @("SHIP MINING", "VEHICLE / ROC", "HAND MINING")
(Find-Control "MiningMethodFilter").Add_SelectionChanged({ Update-MineralOptions })
(Find-Control "MiningMethodFilter").SelectedIndex = 0

(Find-Control "DecodeSignatureButton").Add_Click({
    [double]$scanValue = 0
    $cleanSignature = (Find-Control "SignatureInput").Text -replace '[,\s]', ''
    if (-not (Try-Number $cleanSignature ([ref]$scanValue)) -or $scanValue -le 0) {
        [System.Windows.MessageBox]::Show("Enter a positive scanner signature, such as 10755.", "Invalid signature", "OK", "Warning") | Out-Null
        return
    }

    $allCandidates = @()
    foreach ($signature in $data.signatures) {
        for ($count = 1; $count -le 10; $count++) {
            $expected = [double]$signature.base * $count
            $errorPercent = ([Math]::Abs($scanValue - $expected) / $expected) * 100.0
            $priority = if ($signature.category -eq "Ship-mineable ore") { 0 } else { 1 }
            $allCandidates += [pscustomobject]@{
                name = $signature.name
                category = $signature.category
                method = $signature.method
                count = $count
                base = [double]$signature.base
                expected = $expected
                error = $errorPercent
                priority = $priority
            }
        }
    }

    $closeMatches = @($allCandidates | Where-Object { $_.error -le 0.5 } | Sort-Object error, priority, name)
    $displayMatches = if ($closeMatches.Count -gt 0) {
        @($closeMatches | Select-Object -First 8)
    } else {
        @($allCandidates | Sort-Object error, priority, name | Select-Object -First 5)
    }

    $signatureRows.Clear()
    foreach ($candidate in $displayMatches) {
        $signatureRows.Add([pscustomobject]@{
            name = $candidate.name
            category = $candidate.category
            count = $candidate.count
            baseDisplay = "{0:N0}" -f $candidate.base
            errorDisplay = "{0:N2}%" -f $candidate.error
        })
    }

    $resultName = Find-Control "SignatureResultName"
    $resultDetail = Find-Control "SignatureResultDetail"
    $confidence = Find-Control "SignatureConfidence"
    $best = $displayMatches[0]

    if ($closeMatches.Count -eq 0) {
        $resultName.Text = "NO CLOSE MATCH"
        $resultName.Foreground = "#ED6A5A"
        $resultDetail.Text = "Nearest: {0} x{1} (expected {2:N0} RS)" -f $best.name, $best.count, $best.expected
        $confidence.Text = "CHECK READING"
        $confidence.Foreground = "#ED6A5A"
    } else {
        $resultName.Text = $best.name.ToUpperInvariant()
        $resultName.Foreground = "#FFB87A"
        $extraText = if ($closeMatches.Count -gt 1) { " | $($closeMatches.Count - 1) alternate match(es)" } else { "" }
        $resultDetail.Text = "{0} rock(s) x {1:N0} base RS | {2}{3}" -f $best.count, $best.base, $best.method, $extraText
        if ($best.error -le 0.05) {
            $confidence.Text = "EXACT MATCH"
            $confidence.Foreground = "#5EE6A8"
        } else {
            $confidence.Text = "LIKELY MATCH"
            $confidence.Foreground = "#F6C85F"
        }

    }
})

(Find-Control "SignatureInput").Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.Key -eq [System.Windows.Input.Key]::Return) {
        (Find-Control "DecodeSignatureButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    }
})

(Find-Control "AssessButton").Add_Click({
    [double]$mass = 0
    [double]$resistance = 0
    [double]$instability = 0
    if (-not (Try-Number (Find-Control "RockMass").Text ([ref]$mass)) -or
        -not (Try-Number (Find-Control "Resistance").Text ([ref]$resistance)) -or
        -not (Try-Number (Find-Control "Instability").Text ([ref]$instability)) -or
        $mass -le 0 -or $resistance -lt 0 -or $instability -lt 0) {
        [System.Windows.MessageBox]::Show("Enter valid positive scan values.", "Invalid scan", "OK", "Warning") | Out-Null
        return
    }

    $loadout = Get-CurrentLoadout
    if ($null -eq $loadout) {
        [System.Windows.MessageBox]::Show("Activate at least one mining head.", "Incomplete loadout", "OK", "Warning") | Out-Null
        return
    }

    $effectiveResistance = [Math]::Max(0, $resistance * (1.0 + ([double]$loadout.resistance / 100.0)))
    $effectiveInstability = [Math]::Max(0, $instability * (1.0 + ([double]$loadout.instability / 100.0)))
    $difficulty = ($mass / 5000.0) * (1.0 + ($effectiveResistance / 100.0)) * (1.0 + ($effectiveInstability / 12.0))
    $margin = ([double]$loadout.power / [Math]::Max(0.05, $difficulty)) * 100
    $status = Find-Control "AssessmentStatus"
    $score = Find-Control "AssessmentScore"
    $detail = Find-Control "AssessmentDetail"
    $activeNote = if ($loadout.activeModules.Count -gt 0) {
        " Active module effects are treated as engaged: $($loadout.activeModules -join ', ')."
    } else {
        ""
    }

    if ($margin -ge 135) {
        $status.Text = "GOOD MARGIN"
        $status.Foreground = "#5EE6A8"
        $detail.Text = "This loadout appears comfortably matched to the deposit. Start low, stabilize the charge, and watch for unexpected instability.$activeNote"
    } elseif ($margin -ge 85) {
        $status.Text = "WORKABLE"
        $status.Foreground = "#F6C85F"
        $detail.Text = "The loadout appears near its practical range. A different head, modules, gadget, or an additional coordinated laser may improve control.$activeNote"
    } else {
        $status.Text = "HIGH RISK"
        $status.Foreground = "#ED6A5A"
        $detail.Text = "The deposit appears poorly matched to this loadout. Consider more laser power, resistance reduction, a gadget, or a smaller rock.$activeNote"
    }
    $score.Text = "Estimated margin: {0:N0}%  |  effective resistance {1:N1}%  |  instability {2:N1}" -f $margin, $effectiveResistance, $effectiveInstability
})
$script:assessmentReady = $true
Update-LoadoutStats

function Show-CargoMode([string]$mode) {
    $showTrade = $mode -eq "Trade"
    (Find-Control "CargoValuePanel").Visibility = if ($showTrade) { "Collapsed" } else { "Visible" }
    (Find-Control "TradeRoutesPanel").Visibility = if ($showTrade) { "Visible" } else { "Collapsed" }
    $valueButton = Find-Control "CargoValueModeButton"
    $tradeButton = Find-Control "TradeModeButton"
    $valueButton.Background = if ($showTrade) { "#242033" } else { "#49334B" }
    $valueButton.BorderBrush = if ($showTrade) { "#4C405D" } else { "#FFB87A" }
    $valueButton.Foreground = if ($showTrade) { "#EEE5F4" } else { "#C7B5EF" }
    $tradeButton.Background = if ($showTrade) { "#49334B" } else { "#242033" }
    $tradeButton.BorderBrush = if ($showTrade) { "#FFB87A" } else { "#4C405D" }
    $tradeButton.Foreground = if ($showTrade) { "#C7B5EF" } else { "#EEE5F4" }
}

(Find-Control "CargoValueModeButton").Add_Click({ Show-CargoMode "Value" })
(Find-Control "TradeModeButton").Add_Click({ Show-CargoMode "Trade" })

$tradeRouteRows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
(Find-Control "TradeRoutesGrid").ItemsSource = $tradeRouteRows

function Update-TradeItemOptions {
    $category = [string](Find-Control "TradeCategorySelect").SelectedItem
    $previous = [string](Find-Control "TradeItemSelect").SelectedItem
    if ($category -eq "COMMODITIES") {
        $mineralNames = @{}
        foreach ($name in @($tradeMineralOptions | Where-Object { $_ -ne "ALL MINERALS" })) {
            $mineralNames[([string]$name).ToLowerInvariant()] = $true
        }
        $items = @("ALL COMMODITIES") + @(
            $script:uexPriceRows |
                ForEach-Object { [string]$_.commodity_name } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_) -and
                    -not $mineralNames.ContainsKey($_.ToLowerInvariant())
                } |
                Sort-Object -Unique
        )
    } else {
        $items = $tradeMineralOptions
    }
    (Find-Control "TradeItemSelect").ItemsSource = $items
    (Find-Control "TradeItemSelect").SelectedItem = if ($items -contains $previous) { $previous } else { $items[0] }
}

function Update-TradeSystemOptions {
    $previous = [string](Find-Control "TradeSystemSelect").SelectedItem
    $script:uexTerminalSystemById = @{}
    $script:uexTerminalById = @{}
    foreach ($terminal in @($script:uexTerminalRows)) {
        $script:uexTerminalById[[int]$terminal.id] = $terminal
        $systemName = [string]$terminal.star_system_name
        if (-not [string]::IsNullOrWhiteSpace($systemName)) {
            $script:uexTerminalSystemById[[int]$terminal.id] = $systemName
        }
    }
    $downloadedSystems = @(
        $script:uexTerminalRows |
            ForEach-Object { [string]$_.star_system_name } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $systems = @($tradeSystemOptions)
    foreach ($systemName in $downloadedSystems) {
        if ($systems -notcontains $systemName) {
            $systems += $systemName
        }
    }
    (Find-Control "TradeSystemSelect").ItemsSource = $systems
    (Find-Control "TradeSystemSelect").SelectedItem = if ($systems -contains $previous) { $previous } else { $systems[0] }
}

function Get-TradeTerminalLabel([object]$priceRow) {
    $shortName = [string]$priceRow.terminal_name
    $terminalId = [int]$priceRow.id_terminal
    if (-not $script:uexTerminalById.ContainsKey($terminalId)) {
        return $shortName
    }
    $terminal = $script:uexTerminalById[$terminalId]
    $terminalName = [string]$terminal.name
    $locationName = [string]$terminal.displayname
    if ([string]::IsNullOrWhiteSpace($terminalName)) { $terminalName = $shortName }
    if ([string]::IsNullOrWhiteSpace($locationName) -or $locationName -eq $terminalName) {
        return $terminalName
    }
    return "$locationName | $terminalName"
}

function Get-RankedTradeRoutes(
    [object[]]$priceRows,
    [double]$cargoCapacity,
    [double]$budget,
    [string]$commodityFilter,
    [string]$originFilter,
    [string]$systemFilter,
    [hashtable]$terminalSystemById
) {
    $routes = @()
    $commodityTerm = $commodityFilter.Trim()
    $originTerm = $originFilter.Trim()
    $systemTerm = $systemFilter.Trim()
    $eligibleRows = if ([string]::IsNullOrWhiteSpace($systemTerm) -or $systemTerm -eq "ALL SYSTEMS") {
        @($priceRows)
    } else {
        @($priceRows | Where-Object {
            $terminalSystemById.ContainsKey([int]$_.id_terminal) -and
            $terminalSystemById[[int]$_.id_terminal] -eq $systemTerm
        })
    }
    $groups = @($eligibleRows | Where-Object {
        [double]$_.price_buy -gt 0 -or [double]$_.price_sell -gt 0
    } | Group-Object id_commodity)

    foreach ($group in $groups) {
        $commodityName = [string]$group.Group[0].commodity_name
        if (-not [string]::IsNullOrWhiteSpace($commodityTerm) -and
            $commodityName.IndexOf($commodityTerm, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            continue
        }

        $destinations = @($group.Group | Where-Object { [double]$_.price_sell -gt 0 } | Sort-Object @{ Expression = { [double]$_.price_sell }; Descending = $true })
        if ($destinations.Count -eq 0) { continue }

        foreach ($origin in @($group.Group | Where-Object { [double]$_.price_buy -gt 0 })) {
            $originName = Get-TradeTerminalLabel $origin
            if (-not [string]::IsNullOrWhiteSpace($originTerm) -and
                $originName.IndexOf($originTerm, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                continue
            }
            $destination = $destinations | Where-Object { [int]$_.id_terminal -ne [int]$origin.id_terminal } | Select-Object -First 1
            if ($null -eq $destination) { continue }

            [double]$buyPrice = $origin.price_buy
            [double]$sellPrice = $destination.price_sell
            [double]$margin = $sellPrice - $buyPrice
            if ($margin -le 0) { continue }

            [double]$routeScu = [Math]::Floor($cargoCapacity)
            if ($budget -gt 0) {
                $routeScu = [Math]::Min($routeScu, [Math]::Floor($budget / $buyPrice))
            }
            if ($routeScu -lt 1) { continue }

            [double]$investment = $routeScu * $buyPrice
            [double]$profit = $routeScu * $margin
            [double]$roi = ($margin / $buyPrice) * 100.0
            $routes += [pscustomobject]@{
                commodity = $commodityName
                buyAt = $originName
                sellAt = Get-TradeTerminalLabel $destination
                buyDisplay = "{0:N0}" -f $buyPrice
                sellDisplay = "{0:N0}" -f $sellPrice
                cargoDisplay = "{0:N0}" -f $routeScu
                roiDisplay = "{0:N1}%" -f $roi
                investmentDisplay = "{0:N0}" -f $investment
                profitDisplay = "{0:N0}" -f $profit
                profit = $profit
                roi = $roi
            }
        }
    }
    return @($routes | Sort-Object @{ Expression = "profit"; Descending = $true }, @{ Expression = "roi"; Descending = $true } | Select-Object -First 200)
}

(Find-Control "FindTradeRoutesButton").Add_Click({
    [double]$cargoCapacity = 0
    [double]$budget = 0
    if (-not (Try-Number (Find-Control "TradeCargoScu").Text ([ref]$cargoCapacity)) -or $cargoCapacity -lt 1 -or
        -not (Try-Number (Find-Control "TradeBudget").Text ([ref]$budget)) -or $budget -lt 0) {
        [System.Windows.MessageBox]::Show("Enter cargo capacity of at least 1 SCU and a budget of 0 or greater.", "Invalid trade filters", "OK", "Warning") | Out-Null
        return
    }

    $button = Find-Control "FindTradeRoutesButton"
    $status = Find-Control "TradeStatus"
    $button.IsEnabled = $false
    $needsDownload = $script:uexPriceRows.Count -eq 0
    $button.Content = if ($needsDownload) { "LOADING UEX..." } else { "CALCULATING..." }
    $status.Text = if ($needsDownload) { "Downloading current UEX commodity prices once for this session..." } else { "Recalculating from the loaded UEX price data..." }
    $status.Foreground = "#F6C85F"
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

    if ($needsDownload) {
        $cacheDirectory = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "OreOps"
        $cachePath = Join-Path $cacheDirectory "uex-commodity-prices.json"
        $usedCache = $false
        $webClient = $null
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $webClient = New-Object Net.WebClient
            $jsonText = $webClient.DownloadString("https://api.uexcorp.uk/2.0/commodities_prices_all")
            $response = $jsonText | ConvertFrom-Json
            if ($response.status -ne "ok" -or @($response.data).Count -eq 0) {
                throw "UEX returned an empty or invalid price response."
            }
            New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
            [IO.File]::WriteAllText($cachePath, $jsonText, (New-Object Text.UTF8Encoding($false)))
        } catch {
            if (-not (Test-Path -LiteralPath $cachePath)) {
                $status.Text = "UEX price download failed and no cached data is available."
                $status.Foreground = "#ED6A5A"
                [System.Windows.MessageBox]::Show("Live UEX pricing could not be downloaded.`n`n$($_.Exception.Message)", "UEX trade routes", "OK", "Warning") | Out-Null
                $button.IsEnabled = $true
                $button.Content = "FIND LIVE ROUTES"
                return
            }
            $response = Get-Content -Raw -LiteralPath $cachePath | ConvertFrom-Json
            $usedCache = $true
        } finally {
            if ($null -ne $webClient) { $webClient.Dispose() }
        }
        $script:uexPriceRows = @($response.data)
        $script:uexPriceSource = if ($usedCache) { "cached UEX data" } else { "live UEX data" }

        $terminalCachePath = Join-Path $cacheDirectory "uex-terminals.json"
        $terminalClient = $null
        try {
            $terminalClient = New-Object Net.WebClient
            $terminalJsonText = $terminalClient.DownloadString("https://api.uexcorp.uk/2.0/terminals")
            $terminalResponse = $terminalJsonText | ConvertFrom-Json
            if ($terminalResponse.status -ne "ok" -or @($terminalResponse.data).Count -eq 0) {
                throw "UEX returned an empty or invalid terminal response."
            }
            [IO.File]::WriteAllText($terminalCachePath, $terminalJsonText, (New-Object Text.UTF8Encoding($false)))
        } catch {
            if (Test-Path -LiteralPath $terminalCachePath) {
                $terminalResponse = Get-Content -Raw -LiteralPath $terminalCachePath | ConvertFrom-Json
            } else {
                $terminalResponse = [pscustomobject]@{ data = @() }
            }
        } finally {
            if ($null -ne $terminalClient) { $terminalClient.Dispose() }
        }
        $script:uexTerminalRows = @($terminalResponse.data)
        Update-TradeItemOptions
        Update-TradeSystemOptions
    }

    try {
        $selectedItem = [string](Find-Control "TradeItemSelect").SelectedItem
        $itemFilter = if ($selectedItem -like "ALL *") { "" } else { $selectedItem }
        $rankedRoutes = Get-RankedTradeRoutes $script:uexPriceRows $cargoCapacity $budget $itemFilter (Find-Control "TradeOriginFilter").Text (Find-Control "TradeSystemSelect").SelectedItem $script:uexTerminalSystemById
        $tradeRouteRows.Clear()
        foreach ($route in $rankedRoutes) { $tradeRouteRows.Add($route) }
        $status.Text = "$($rankedRoutes.Count) profitable routes ranked by estimated haul profit using $($script:uexPriceSource). Selection changes reuse this loaded dataset."
        $status.Foreground = if ($script:uexPriceSource -like "cached*") { "#F6C85F" } else { "#5EE6A8" }
    } catch {
        $status.Text = "Trade route search failed."
        $status.Foreground = "#ED6A5A"
        [System.Windows.MessageBox]::Show("Trade routes could not be calculated.`n`n$($_.Exception.Message)", "UEX trade routes", "OK", "Warning") | Out-Null
    } finally {
        $button.IsEnabled = $true
    }
})

(Find-Control "TradeCategorySelect").Add_SelectionChanged({
    Update-TradeItemOptions
    (Find-Control "FindTradeRoutesButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
})

(Find-Control "TradeItemSelect").Add_SelectionChanged({
    if ($script:uexPriceRows.Count -gt 0) {
        (Find-Control "FindTradeRoutesButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    }
})

(Find-Control "TradeSystemSelect").Add_SelectionChanged({
    if ($script:uexPriceRows.Count -gt 0) {
        (Find-Control "FindTradeRoutesButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    }
})

(Find-Control "CalculateButton").Add_Click({
    [double]$scu = 0
    [double]$purity = 0
    [double]$yield = 0
    if (-not (Try-Number (Find-Control "CargoScu").Text ([ref]$scu)) -or
        -not (Try-Number (Find-Control "CargoPurity").Text ([ref]$purity)) -or
        -not (Try-Number (Find-Control "RefineryYield").Text ([ref]$yield)) -or
        $scu -lt 0 -or $purity -lt 0 -or $purity -gt 100 -or $yield -lt 0 -or $yield -gt 100) {
        [System.Windows.MessageBox]::Show("Use valid values: SCU must be 0 or greater and percentages from 0 to 100.", "Invalid cargo", "OK", "Warning") | Out-Null
        return
    }
    $ore = $data.ores[(Find-Control "CargoOreSelect").SelectedIndex]
    $oreScu = $scu * ($purity / 100.0)
    $refinedScu = $oreScu * ($yield / 100.0)
    $rawValue = $oreScu * [double]$ore.raw
    $refinedValue = $refinedScu * [double]$ore.refined
    (Find-Control "RawValue").Text = "{0:N0} aUEC" -f $rawValue
    (Find-Control "RawDetail").Text = "{0:N2} SCU of {1} at {2:N0} / SCU" -f $oreScu, $ore.name, $ore.raw
    (Find-Control "RefinedValue").Text = "{0:N0} aUEC" -f $refinedValue
    (Find-Control "RefinedDetail").Text = "{0:N2} SCU after {1:N0}% refinery yield" -f $refinedScu, $yield
})

$appData = [Environment]::GetFolderPath("LocalApplicationData")
$runDirectory = Join-Path $appData "OreOps"
$runPath = Join-Path $runDirectory "runs.json"
$runs = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

function Update-RefineryJobNotification {
    $status = Find-Control "RefineryJobStatus"
    $detail = Find-Control "RefineryJobDetail"
    $card = Find-Control "RefineryJobCard"
    $card.BorderBrush = "#4C405D"
    $status.Foreground = "#C7B5EF"
    $changed = $false
    foreach ($run in $runs) {
        $display = "No timer"
        if ($run.dueAt) {
            $left = [DateTimeOffset]::Parse($run.dueAt) - [DateTimeOffset]::UtcNow
            $display = if ($left.TotalSeconds -le 0) { "Completed" } elseif ($left.TotalSeconds -lt 60) {
                "{0}s" -f [int][Math]::Ceiling($left.TotalSeconds)
            } else {
                $seconds = [long][Math]::Ceiling($left.TotalSeconds)
                "{0}h {1:00}m {2:00}s" -f [long][Math]::Floor($seconds / 3600), [int][Math]::Floor(($seconds % 3600) / 60), ($seconds % 60)
            }
        }
        if ($run.timerDisplay -ne $display) { $run.timerDisplay = $display; $changed = $true }
    }
    if ($changed) { (Find-Control "RunGrid").Items.Refresh() }
    $completedRuns = @($runs | Where-Object { $_.dueAt -and [DateTimeOffset]::Parse($_.dueAt) -le [DateTimeOffset]::UtcNow })
    (Find-Control "DeleteAllCompletedJobs").IsEnabled = $completedRuns.Count -gt 0
    $selectedRun = (Find-Control "RunGrid").SelectedItem
    (Find-Control "DeleteCompletedJob").IsEnabled = $null -ne $selectedRun
    if ($completedRuns.Count -gt 0) {
        $status.Text = if ($completedRuns.Count -eq 1) { "Job completed" } else { "$($completedRuns.Count) jobs completed" }
        $status.Foreground = "#5EE6A8"
        $card.BorderBrush = "#5EE6A8"
        $detail.Text = "$($completedRuns[0].ore) / $($completedRuns[0].location)"
        $detail.ToolTip = ($completedRuns | ForEach-Object { "$($_.ore) / $($_.location)" }) -join "`n"
        return
    }
    $activeRuns = @($runs | Where-Object { $_.dueAt -and [DateTimeOffset]::Parse($_.dueAt) -gt [DateTimeOffset]::UtcNow } | Sort-Object dueAt)
    if ($activeRuns.Count -gt 0) {
        $status.Text = "$($activeRuns[0].timerDisplay) remaining"
        $detail.Text = "$($activeRuns[0].ore) / $($activeRuns[0].location)"
        $detail.ToolTip = "$($activeRuns.Count) active job(s)`n$($detail.Text)"
        return
    }
    $status.Text = "No active job"
    $detail.Text = "Set timers in the Run Log"
    $detail.ToolTip = $detail.Text
}
Update-RefineryJobNotification
$refineryTimer = [System.Windows.Threading.DispatcherTimer]::new()
$refineryTimer.Interval = [TimeSpan]::FromSeconds(1)
$refineryTimer.Add_Tick({ Update-RefineryJobNotification })
$refineryTimer.Start()
$window.Add_Closed({ $refineryTimer.Stop() })

function Add-RunToCollection($run) {
    $dueAt = [string]$run.dueAt
    if ($dueAt) {
        try { $null = [DateTimeOffset]::Parse($dueAt) } catch { $dueAt = "" }
    }
    $runs.Add([pscustomobject]@{
        id = if ($run.id) { [string]$run.id } else { [guid]::NewGuid().ToString() }
        date = [string]$run.date
        location = [string]$run.location
        ore = [string]$run.ore
        scu = [double]$run.scu
        value = [double]$run.value
        valueDisplay = "{0:N0} aUEC" -f [double]$run.value
        dueAt = $dueAt
        completionDismissed = [bool]$run.completionDismissed
        timerDisplay = "No timer"
    })
}

function Save-Runs {
    New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
    $savedRuns = @($runs | ForEach-Object {
        [pscustomobject]@{ id = $_.id; date = $_.date; location = $_.location; ore = $_.ore; scu = $_.scu; value = $_.value; dueAt = $_.dueAt; completionDismissed = $_.completionDismissed }
    })
    ConvertTo-Json -InputObject $savedRuns | Set-Content -LiteralPath $runPath -Encoding UTF8
}

if (Test-Path -LiteralPath $runPath) {
    try {
        $storedRuns = Get-Content -Raw -LiteralPath $runPath | ConvertFrom-Json
        foreach ($run in $storedRuns) { Add-RunToCollection $run }
    } catch {
        # A damaged personal log should not prevent the app from opening.
    }
}
function Remove-CompletedRuns([bool]$all) {
    $selectedRun = (Find-Control "RunGrid").SelectedItem
    $toDelete = @($runs | Where-Object {
        if ($all) {
            $_.dueAt -and [DateTimeOffset]::Parse($_.dueAt) -le [DateTimeOffset]::UtcNow
        } else {
            $null -ne $selectedRun -and $_.id -eq $selectedRun.id
        }
    })
    if ($toDelete.Count -eq 0) { return }
    $before = @($runs)
    try {
        foreach ($run in $toDelete) { $null = $runs.Remove($run) }
        Save-Runs
    } catch {
        $runs.Clear()
        foreach ($run in $before) { $runs.Add($run) }
        [System.Windows.MessageBox]::Show($window, "Could not save the deletion. Your jobs have been restored.", "Run log") | Out-Null
    }
    (Find-Control "RunCount").Text = [string]$runs.Count
    Update-RefineryJobNotification
}
(Find-Control "DeleteCompletedJob").Add_Click({ Remove-CompletedRuns $false })
(Find-Control "DeleteAllCompletedJobs").Add_Click({ Remove-CompletedRuns $true })
(Find-Control "RunGrid").Add_SelectionChanged({ Update-RefineryJobNotification })
(Find-Control "RunGrid").ItemsSource = $runs
(Find-Control "RunCount").Text = [string]$runs.Count
(Find-Control "RunHours").ItemsSource = @(0..168)
(Find-Control "RunMinutes").ItemsSource = @(0..59)
(Find-Control "RunHours").SelectedIndex = 1
(Find-Control "RunMinutes").SelectedIndex = 0
Update-RefineryJobNotification
(Find-Control "RunLocation").ItemsSource = @($data.refineryLocations)
(Find-Control "RunLocation").Add_SelectionChanged({
    (Find-Control "RunLocation").ToolTip = [string](Find-Control "RunLocation").SelectedItem
})

(Find-Control "SaveRunButton").Add_Click({
    [double]$scu = 0
    $durationMinutes = ([int](Find-Control "RunHours").SelectedItem * 60) + [int](Find-Control "RunMinutes").SelectedItem
    $location = [string](Find-Control "RunLocation").SelectedItem
    if ([string]::IsNullOrWhiteSpace($location) -or
        -not (Try-Number (Find-Control "RunScu").Text ([ref]$scu)) -or
        $scu -lt 0 -or $durationMinutes -le 0) {
        [System.Windows.MessageBox]::Show("Choose a refinery, enter valid non-negative SCU, and select a timer greater than zero.", "Incomplete run", "OK", "Warning") | Out-Null
        return
    }

    $newRun = [pscustomobject]@{
        date = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        location = $location
        ore = [string](Find-Control "RunOreSelect").SelectedItem
        scu = $scu
        value = 0
        dueAt = [DateTimeOffset]::UtcNow.AddMinutes($durationMinutes).ToString("o")
        completionDismissed = $false
    }
    Add-RunToCollection $newRun
    try { Save-Runs } catch {
        $runs.RemoveAt($runs.Count - 1)
        [System.Windows.MessageBox]::Show($window, "Could not save the run and timer. Please try again.", "Run log") | Out-Null
        return
    }
    Update-RefineryJobNotification
    (Find-Control "RunCount").Text = [string]$runs.Count
    (Find-Control "RunLocation").SelectedIndex = -1
})

(Find-Control "CalculateButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
(Find-Control "DecodeSignatureButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
$script:overlayFontSize = 17
$script:overlayFontPercent = 0
$settingsPath = Join-Path $runDirectory 'settings.json'
if (Test-Path -LiteralPath $settingsPath) {
    try {
        $savedSettings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
        if ($savedSettings.PSObject.Properties['overlayFontPercent']) {
            [double]$savedPercent = $savedSettings.overlayFontPercent
        } else {
            [double]$savedSize = $savedSettings.overlayFontSize
            $savedPercent = if ($savedSize -ge 12 -and $savedSize -le 36) { ($savedSize / 17 - 1) * 100 } else { 0 }
        }
        if (-not [double]::IsNaN($savedPercent)) {
            $script:overlayFontPercent = [Math]::Max(-50, [Math]::Min(50, [Math]::Round($savedPercent / 10) * 10))
        }
    } catch { (Find-Control 'SettingsStatus').Text = 'Saved settings could not be read. Default lettering size is in use.' }
}
. (Join-Path $PSScriptRoot 'ScanOverlay.ps1')
(Find-Control 'OverlayCoverage').Text = "Signature coverage: $(@($data.signatures | Where-Object { $_.category -eq 'Ship-mineable ore' }).Count) ship ores, clusters of 1-10. ROC/hand-mining signatures indicate deposit size, not a specific gem. Matches depend on the bundled patch data and a readable HUD."
function Update-OverlayFontSetting {
    $script:overlayFontPercent = [Math]::Round((Find-Control 'OverlayFontSizeSlider').Value / 10) * 10
    $script:overlayFontSize = 17 * (1 + $script:overlayFontPercent / 100)
    $percentLabel = if ($script:overlayFontPercent -gt 0) { "+$($script:overlayFontPercent)%" } else { "$($script:overlayFontPercent)%" }
    (Find-Control 'OverlayFontSizeLabel').Text = "Lettering size: $percentLabel"
    (Find-Control 'OverlayFontPreview').FontSize = $script:overlayFontSize
    if ($script:scanOverlayText) { $script:scanOverlayText.FontSize = $script:overlayFontSize }
}
(Find-Control 'OverlayFontSizeSlider').Value = $script:overlayFontPercent
Update-OverlayFontSetting
if (-not $ValidateUi) { Toggle-ScanOverlay }
(Find-Control 'OverlayFontSizeSlider').Add_ValueChanged({
    Update-OverlayFontSetting
    (Find-Control 'SettingsStatus').Text = 'Size applied. Save settings to keep it for next time.'
})
(Find-Control 'SaveSettings').Add_Click({
    try {
        New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
        @{ overlayFontPercent = $script:overlayFontPercent; overlayFontSize = $script:overlayFontSize } | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
        (Find-Control 'SettingsStatus').Text = 'Settings saved.'
    } catch { (Find-Control 'SettingsStatus').Text = 'Could not save settings. The current size remains applied for this session.' }
})
Show-Page "Dashboard" "OPERATIONS DASHBOARD" "Plan the rock. Protect the ship. Maximize the haul."
if ($ValidateUi) {
    $originalRuns = $runs
    $originalRunPath = $runPath
    $runs = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
    (Find-Control "RunGrid").ItemsSource = $runs
    $runPath = Join-Path ([IO.Path]::GetTempPath()) ("oreops-runs-test-" + [guid]::NewGuid() + ".json")
    try {
        (Find-Control "RunLocation").SelectedIndex = 0
        (Find-Control "RunHours").SelectedIndex = 2
        (Find-Control "RunMinutes").SelectedIndex = 15
        (Find-Control "SaveRunButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        if ($runs.Count -ne 1 -or $runs[0].timerDisplay -notmatch '^2h (14|15)m [0-5][0-9]s$') { throw "Run timer was not started." }
        (Find-Control "RunLocation").SelectedIndex = 1
        (Find-Control "SaveRunButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        (Find-Control "RunGrid").SelectedIndex = 1
        Remove-CompletedRuns $true
        if ($runs.Count -ne 2) { throw "An active job was deleted." }
        $runs[0].dueAt = [DateTimeOffset]::UtcNow.AddSeconds(-1).ToString("o")
        Update-RefineryJobNotification
        if ((Find-Control "RefineryJobStatus").Text -ne "Job completed") { throw "Completion notification missing." }
        (Find-Control "RunGrid").SelectedItem = $runs[0]
        (Find-Control "DeleteCompletedJob").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        if ($runs.Count -ne 1 -or (Find-Control "RefineryJobStatus").Text -eq "Job completed") { throw "Individual deletion did not update the dashboard." }
        $savedRuns = Get-Content -Raw -LiteralPath $runPath | ConvertFrom-Json
        $runs.Clear()
        foreach ($savedRun in $savedRuns) { Add-RunToCollection $savedRun }
        if ($runs.Count -ne 1) { throw "Deletion was not persisted." }
        Add-RunToCollection ([pscustomobject]@{ location="Legacy"; ore="Gold"; scu=1; value=10 })
        Add-RunToCollection ([pscustomobject]@{ location="Active"; ore="Gold"; scu=1; dueAt=[DateTimeOffset]::UtcNow.AddHours(1).ToString("o") })
        $runs[0].dueAt = [DateTimeOffset]::UtcNow.AddSeconds(-1).ToString("o")
        Add-RunToCollection ([pscustomobject]@{ location="Complete"; ore="Gold"; scu=1; dueAt=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToString("o") })
        Update-RefineryJobNotification
        (Find-Control "DeleteAllCompletedJobs").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        if ($runs.Count -ne 2 -or $runs[0].location -ne "Legacy" -or $runs[1].location -ne "Active") { throw "Bulk deletion removed unfinished jobs or missed completed jobs." }
        $savedRuns = Get-Content -Raw -LiteralPath $runPath | ConvertFrom-Json
        if ($savedRuns.Count -ne 2 -or (Find-Control "DeleteAllCompletedJobs").IsEnabled) { throw "Bulk deletion state was not persisted." }
        (Find-Control "RunGrid").SelectedIndex = 0
        if (-not (Find-Control "DeleteCompletedJob").IsEnabled) { throw "Legacy row cannot be selected for deletion." }
        (Find-Control "DeleteCompletedJob").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        if ($runs.Count -ne 1 -or $runs[0].location -ne "Active") { throw "Legacy row deletion failed." }
        (Find-Control "RunGrid").SelectedIndex = 0
        (Find-Control "DeleteCompletedJob").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        $savedRuns = Get-Content -Raw -LiteralPath $runPath | ConvertFrom-Json
        if ($runs.Count -ne 0 -or @($savedRuns).Count -ne 0 -or (Find-Control "DeleteCompletedJob").IsEnabled) { throw "Deleting the final selected job failed." }
    } finally {
        if (Test-Path -LiteralPath $runPath) { Remove-Item -LiteralPath $runPath }
        $runPath = $originalRunPath
        $runs = $originalRuns
        (Find-Control "RunGrid").ItemsSource = $runs
        (Find-Control "RunCount").Text = [string]$runs.Count
        Update-RefineryJobNotification
    }
    (Find-Control "MineralFilter").SelectedItem = "Gold"
    $allLocationCount = $locationRows.Count
    (Find-Control "SystemFilter").SelectedItem = "Pyro"
    $pyroLocationCount = $locationRows.Count
    (Find-Control "SignatureInput").Text = "3600"
    (Find-Control "DecodeSignatureButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    if ((Find-Control "MineralFilter").SelectedItem -ne "Gold") {
        throw "Decoding an RS signature changed the independent mineral location selection."
    }
    $mineralCount = (Find-Control "MineralFilter").Items.Count
    (Find-Control "SystemFilter").SelectedItem = "All Systems"
    (Find-Control "MiningMethodFilter").SelectedItem = "VEHICLE / ROC"
    $vehicleMineralCount = (Find-Control "MineralFilter").Items.Count
    $hasFeynmaline = (Find-Control "MineralFilter").Items.Contains("Feynmaline")
    (Find-Control "MineralFilter").SelectedItem = "Feynmaline"
    $vehicleLocationCount = $locationRows.Count
    (Find-Control "MiningMethodFilter").SelectedItem = "HAND MINING"
    $handMineralCount = (Find-Control "MineralFilter").Items.Count
    $hasJanalite = (Find-Control "MineralFilter").Items.Contains("Janalite")
    (Find-Control "MineralFilter").SelectedItem = "Janalite"
    $handLocationCount = $locationRows.Count
    if ($vehicleMineralCount -lt 3 -or -not $hasFeynmaline -or $vehicleLocationCount -eq 0 -or
        $handMineralCount -lt 4 -or -not $hasJanalite -or $handLocationCount -eq 0) {
        throw "Vehicle and hand-minable minerals or their fallback locations were not populated correctly."
    }
    (Find-Control "MiningMethodFilter").SelectedItem = "SHIP MINING"
    (Find-Control "MineralFilter").SelectedItem = "Quantainium"
    $quantainiumLocationCount = $locationRows.Count
    if ($mineralCount -lt 26 -or $quantainiumLocationCount -eq 0) {
        throw "The mineral location dropdown did not include and load all known ship-minable minerals."
    }
    $arborWindow = (Find-Control "WindowGraphValue").Text
    $arborResistance = (Find-Control "ResistanceGraphValue").Text
    (Find-Control "Head1Select").SelectedIndex = 1
    if ((Find-Control "WindowGraphValue").Text -eq $arborWindow -and
        (Find-Control "ResistanceGraphValue").Text -eq $arborResistance) {
        throw "Loadout graph did not react to a mining-head change."
    }
    (Find-Control "ShipSelect").SelectedItem = "ARGO MOLE"
    (Find-Control "Head1Select").SelectedIndex = 1
    (Find-Control "Head2Select").SelectedIndex = 2
    (Find-Control "Head3Select").SelectedIndex = 3
    (Find-Control "Head1Module1").SelectedIndex = 11
    (Find-Control "Head2Toggle").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    $twoHeadLoadout = Get-CurrentLoadout
    if ($twoHeadLoadout.heads.Count -ne 2 -or
        (Find-Control "Head2Toggle").Content -ne "INACTIVE" -or
        (Find-Control "Head2Select").IsEnabled) {
        throw "Mining-head deactivation did not update the active loadout and controls."
    }
    (Find-Control "Head2Toggle").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    if ((Get-CurrentLoadout).heads.Count -ne 3 -or
        (Find-Control "Head2Toggle").Content -ne "ACTIVE" -or
        -not (Find-Control "Head2Select").IsEnabled) {
        throw "Mining-head reactivation did not restore the active loadout and controls."
    }
    (Find-Control "GadgetSelect").SelectedItem = "Sabir"
    (Find-Control "AssessButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    if ((Find-Control "ResistanceGraphValue").Foreground.ToString() -notmatch "5EE6A8" -or
        (Find-Control "WindowGraphValue").Foreground.ToString() -notmatch "5EE6A8" -or
        (Find-Control "InstabilityGraphValue").Foreground.ToString() -notmatch "ED6A5A") {
        throw "Graph colors did not match the tested beneficial and harmful modifiers."
    }
    if ((Find-Control "GadgetBenefit").Text -notmatch "Sabir|resistance") {
        throw "Gadget benefits did not update the loadout panel."
    }
    $originalPresetPath = $fitPresetPath
    $originalPresets = $script:fitPresets
    $originalFit = Get-FitPreset "Restore validation fit"
    $fitPresetPath = Join-Path ([IO.Path]::GetTempPath()) ("oreops-presets-" + [guid]::NewGuid() + ".json")
    try {
        $script:fitPresets = @()
        $script:headEnabled[1] = $false
        Update-HeadActivationUi 2
        $expectedFit = Get-FitPreset "Best mining"
        (Find-Control "FitPresetName").Text = "Best mining"
        (Find-Control "SaveFitPreset").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        $storedFits = Get-Content -Raw -LiteralPath $fitPresetPath | ConvertFrom-Json
        (Find-Control "ShipSelect").SelectedIndex = 0
        Set-FitPreset $storedFits[0]
        $restoredFit = Get-FitPreset "Best mining"
        if ((ConvertTo-Json $expectedFit -Depth 8 -Compress) -ne (ConvertTo-Json $restoredFit -Depth 8 -Compress)) {
            throw "Preset did not restore ship, heads, modules, activation, and gadget."
        }
        (Find-Control "SaveFitPreset").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        if ($script:fitPresets.Count -ne 1) { throw "Updating a preset created a duplicate." }
        (Find-Control "ShipSelect").SelectedIndex = 0
        (Find-Control "SaveFitPreset").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        if ($script:fitPresets.Count -ne 2) { throw "Different ships cannot share a preset name." }
        (Find-Control "DeleteFitPreset").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        $storedFits = Get-Content -Raw -LiteralPath $fitPresetPath | ConvertFrom-Json
        if ($storedFits.Count -ne 1 -or $storedFits[0].ship -ne "ARGO MOLE") { throw "Preset deletion removed the wrong ship fit." }
    } finally {
        if (Test-Path -LiteralPath $fitPresetPath) { Remove-Item -LiteralPath $fitPresetPath }
        $fitPresetPath = $originalPresetPath
        $script:fitPresets = $originalPresets
        (Find-Control "FitPresetSelect").ItemsSource = $script:fitPresets
        Set-FitPreset $originalFit
    }
    $testPrices = @(
        [pscustomobject]@{ id_commodity = 1; id_terminal = 10; commodity_name = "Test Cargo"; terminal_name = "Buy Port"; price_buy = 10; price_sell = 0 },
        [pscustomobject]@{ id_commodity = 1; id_terminal = 20; commodity_name = "Test Cargo"; terminal_name = "Sell Port"; price_buy = 0; price_sell = 20 }
    )
    $testTerminalRows = @(
        [pscustomobject]@{ id = 10; star_system_name = "Stanton"; displayname = "Buy City"; name = "Buy Terminal" },
        [pscustomobject]@{ id = 20; star_system_name = "Stanton"; displayname = "Sell Station"; name = "Sell Terminal" }
    )
    $testTerminalSystems = @{ 10 = "Stanton"; 20 = "Stanton" }
    $script:uexPriceRows = $testPrices
    $script:uexTerminalRows = $testTerminalRows
    Update-TradeSystemOptions
    $testTradeRoutes = @(Get-RankedTradeRoutes $testPrices 10 1000 "" "" "ALL SYSTEMS" $testTerminalSystems)
    $tradeSystemLabels = @((Find-Control "TradeSystemSelect").Items)
    (Find-Control "TradeCategorySelect").SelectedItem = "COMMODITIES"
    $tradeCommodityLabels = @((Find-Control "TradeItemSelect").Items)
    (Find-Control "TradeCategorySelect").SelectedItem = "MINERALS"
    $tradeMineralCount = (Find-Control "TradeItemSelect").Items.Count
    $tradeMineralLabels = @((Find-Control "TradeItemSelect").Items)
    $tradeShipCount = (Find-Control "TradeShipSelect").Items.Count
    $hullCOption = @((Find-Control "TradeShipSelect").Items | Where-Object { $_ -eq "MISC Hull C" } | Select-Object -First 1)
    if ($hullCOption.Count -gt 0) {
        (Find-Control "TradeShipSelect").SelectedItem = $hullCOption[0]
    }
    (Find-Control "TradeModeButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    if ($testTradeRoutes.Count -ne 1 -or $testTradeRoutes[0].profitDisplay -ne "100" -or
        $testTradeRoutes[0].buyAt -ne "Buy City | Buy Terminal" -or $testTradeRoutes[0].sellAt -ne "Sell Station | Sell Terminal" -or
        $tradeMineralCount -lt 34 -or $tradeShipCount -ne 39 -or
        (Find-Control "TradeCargoScu").Text -ne "4608" -or
        $tradeSystemLabels -notcontains "ALL SYSTEMS" -or $tradeSystemLabels -notcontains "Stanton" -or
        $tradeSystemLabels -notcontains "Pyro" -or $tradeSystemLabels -notcontains "Nyx" -or
        $tradeCommodityLabels -notcontains "ALL COMMODITIES" -or $tradeCommodityLabels -notcontains "Test Cargo" -or
        $tradeMineralLabels -notcontains "ALL MINERALS" -or $tradeMineralLabels -notcontains "Feynmaline" -or $tradeMineralLabels -notcontains "Janalite" -or
        (Find-Control "TradeRoutesPanel").Visibility -ne "Visible") {
        throw "Trade route ranking, mineral selection, or cargo-mode navigation failed."
    }
    (Find-Control "CargoValueModeButton").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    Write-Output "Mining Helper interface loaded successfully: $($pages.Count) pages. Decoder test: $((Find-Control "SignatureResultName").Text), $mineralCount ship minerals, $vehicleMineralCount vehicle minerals with $vehicleLocationCount Feynmaline locations, $handMineralCount hand minerals with $handLocationCount Janalite locations, $allLocationCount Gold locations, $pyroLocationCount in Pyro, $quantainiumLocationCount Quantainium locations. Trade test: $tradeShipCount cargo ships, $tradeMineralCount mineral choices, Hull C $((Find-Control "TradeCargoScu").Text) SCU, $($testTradeRoutes[0].profitDisplay) profit. Loadout test: $((Find-Control "LoadoutStats").Text), $((Find-Control "EffectiveDps").Text), $((Find-Control "AssessmentStatus").Text). Gadget: $((Find-Control "GadgetBenefit").Text). Graph: instability $((Find-Control "InstabilityGraphValue").Text), window $((Find-Control "WindowGraphValue").Text), resistance $((Find-Control "ResistanceGraphValue").Text), filter $((Find-Control "FilterGraphValue").Text)."
    exit 0
}
Start-LiveVersionCheck
$window.ShowDialog() | Out-Null

