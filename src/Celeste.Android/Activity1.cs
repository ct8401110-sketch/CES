using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Views;
using Android.Runtime;
using Microsoft.Xna.Framework;
using Celeste.Core;

namespace Celeste.Android
{
    [Activity(
        Label = "@string/app_name",
        MainLauncher = true,
        AlwaysRetainTaskState = true,
        LaunchMode = LaunchMode.SingleInstance,
        ScreenOrientation = ScreenOrientation.FullUser,
        ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.Keyboard | ConfigChanges.KeyboardHidden | ConfigChanges.ScreenSize
    )]
    public class Activity1 : Activity
	{
		private Game1 _game;

		protected override void OnCreate(Bundle savedInstanceState)
		{
			base.OnCreate(savedInstanceState);

			// Extrair assets "Content/" para app-specific storage para compatibilidade
			try
			{
				var targetBase = this.GetExternalFilesDir(null)?.AbsolutePath ?? this.FilesDir.AbsolutePath;
				var contentTarget = System.IO.Path.Combine(targetBase, "Content");
				CopyAssetFolder("Content", contentTarget);
				// Ajusta AssemblyDirectory interno do Monocle.Engine para apontar ao app-specific
				var engineType = typeof(Monocle.Engine);
				var field = engineType.GetField("AssemblyDirectory", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
				if (field != null)
				{
					field.SetValue(null, targetBase);
				}
			}
			catch (System.Exception ex)
			{
				Android.Util.Log.Warn("Celeste", "Asset extraction failed: " + ex.Message);
			}

			// Initialize platform and logging
			ServiceLocator.RegisterPlatformService(new AndroidPlatformService(this));
			ServiceLocator.RegisterLogSystem(new AndroidLogSystem(this));

			ServiceLocator.LogSystem.Log("=== CELESTE ANDROID START ===");

			_game = new Game1();
			SetContentView(_game.Services.GetService(typeof(View)) as View);
			_game.Run();
		}

		private void CopyAssetFolder(string assetPath, string destPath)
		{
			var assets = this.Assets;
			System.IO.Directory.CreateDirectory(destPath);
			string[] list = assets.List(assetPath);
			if (list == null || list.Length == 0)
			{
				// arquivo simples
				using (var istream = assets.Open(assetPath))
				using (var of = System.IO.File.Create(destPath))
				{
					istream.CopyTo(of);
				}
				return;
			}

			foreach (var entry in list)
			{
				var fullAsset = assetPath + "/" + entry;
				var subList = assets.List(fullAsset);
				if (subList != null && subList.Length > 0)
				{
					// diretório
					CopyAssetFolder(fullAsset, System.IO.Path.Combine(destPath, entry));
				}
				else
				{
					// arquivo
					using (var istream = assets.Open(fullAsset))
					{
						var outPath = System.IO.Path.Combine(destPath, entry);
						System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(outPath));
						using (var of = System.IO.File.Create(outPath))
						{
							istream.CopyTo(of);
						}
					}
				}
			}
		}

		protected override void OnPause()
		{
			base.OnPause();
			_game?.Dispose();
			ServiceLocator.LogSystem?.Log("Activity paused");
		}

		protected override void OnResume()
		{
			base.OnResume();
			
			// Reaplicar fullscreen e modo imersivo
			ApplyFullscreenMode();
			
			ServiceLocator.LogSystem?.Log("Activity resumed");
		}

		protected override void OnWindowFocusChanged(bool hasFocus)
		{
			base.OnWindowFocusChanged(hasFocus);
			
			if (hasFocus)
			{
				ApplyFullscreenMode();
			}
		}

		private void ApplyFullscreenMode()
		{
			// Fullscreen imersivo sticky (hide system UI even on interaction)
			if (Build.VERSION.SdkInt >= BuildVersionCodes.Kitkat)
			{
				var immersiveFlags = (SystemUiFlags)0x00001000 | // FLAG_IMMERSIVE_STICKY
					SystemUiFlags.HideNavigation | 
					SystemUiFlags.HideSystemUi |
					SystemUiFlags.LayoutHideNavigation |
					SystemUiFlags.LayoutFullscreen |
					SystemUiFlags.Fullscreen;

				Window.DecorView.SystemUiVisibility = (StatusBarVisibility)immersiveFlags;
			}
			else
			{
				// Fallback para older Android
				var flags = SystemUiFlags.HideNavigation | SystemUiFlags.HideSystemUi;
				Window.DecorView.SystemUiVisibility = (StatusBarVisibility)flags;
			}
		}
	}
}
