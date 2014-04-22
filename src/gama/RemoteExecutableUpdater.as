package gama
{
	/**
	 * 这个实现是一个基于函数编程的线性过程
	 *
	 * 设个实现设计的考量如下：
	 * 1. 应该尽可能少的占用内存 —— 所以是一个单例的静态实现，所以只转手二进制而不持有二进制
	 * 2. 应该努力释放不再使用的内容 —— 所以在过程中所创建的对象放在本地变量中，然后用动态创建的监听方法进行监听处理
	 */
	import flash.display.Loader;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;

	public class RemoteExecutableUpdater
	{
		static private const PATH_LOCAL_CACHE_VERSION:String = "gama/reu/version";

		static private const PATH_LOCAL_CACHE_EXECUTABLE:String = "gama/reu/executable";

		static public const LOADER_CONTEXT:LoaderContext = new LoaderContext ;
		LOADER_CONTEXT.allowCodeImport = true;

		/**
		 * 繁忙锁
		 */
		static private var isBusy:Boolean = false;

		/**
		 * 事件派发器
		 */
		static private var dispatcher:EventDispatcher = new EventDispatcher ;

		/**
		 * 本地的swf 版本
		 */
		static private var _localVersion:int ;

		/**
		 * 本地缓存的的swf 版本
		 * 如果获取版本失败，那么值为 -1
		 */
		static private var _localCachedVersion:int ;

		/**
		 * 远端的 swf 版本
		 * 如果获取版本失败，那么值为 -1
		 */
		static private var _remoteVersion:int ;

		/**
		 * 本地的 swf 文件
		 */
		static private var _localExecutable:File ;

		/**
		 * 读取远端 swf 版本的 url
		 */
		static private var _remoteVersionUrl:String ;

		/**
		 * 远端的 swf url
		 */
		static private var _remoteExecutableUrl:String;

		/**
		 * swf内容的加载器
		 */
		static public var loader:Loader = new Loader;

		/**
		 * 开始整个步骤
		 * @param localVersion
		 * @param localExecutable
		 * @param remoteVersionUrl
		 * @param remoteExecutableUrl [可选] 如果提供这个参数，那么使用所提供的参数，如果不提供，那么尝试使用远端的数据 json 中的 url 属性
		 */
		static public function start(localVersion:int, localExecutable:File, remoteVersionUrl:String, remoteExecutableUrl:String = null):void
		{
			if(localExecutable == null)
			{
				throw(new Error("bad argument: localExecutable:"+localExecutable));
				return;
			}

			if(localExecutable.exists === false)
			{
				throw(new Error("non-exist localExecutable:"+localExecutable));
				return;
			}
			
			if(remoteVersionUrl == null)
			{
				throw(new Error("bad argument: remoteVersionUrl:"+remoteVersionUrl));
				return;
			}

			if(isBusy)
			{
				dispatcher.dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "RemoteExecutableUpdater is running"));
				return;
			}

			_localVersion = localVersion;

			_localExecutable = localExecutable;

			_remoteVersionUrl = remoteVersionUrl;

			_remoteExecutableUrl = remoteExecutableUrl;

			isBusy = true;

			readLocalCachedVersion();

			readRemoteSwfVersion();
		}

		/**
		 * 读出本地缓存的swf 的版本
		 */
		static private function readLocalCachedVersion():void
		{
			var file:File = File.applicationStorageDirectory.resolvePath(PATH_LOCAL_CACHE_VERSION);
			if(file.exists === false)
			{
				_localCachedVersion = -1;
				return;
			}
			var ba:ByteArray = readLocalFile(file);
			ba.position = 0;
			_localCachedVersion = ba.readUnsignedInt();
			return;
		}

		/**
		 * 结束整个过程
		 * @param event
		 */
		static private function end(event:Event):void
		{
			trace("[RemoteExecutableUpdater.end] event:"+event);
			_localExecutable = null;
			_remoteVersionUrl = null;
			_remoteExecutableUrl = null;
			_localVersion = 0;
			isBusy = false;
			if(event)
			{
				if(event.type !== Event.COMPLETE)
				{
					/* 如果不是载入成功的话，移除对外暴露的 loader */
					loader = null;
				}
				dispatcher.dispatchEvent(event);
			}
		}

		/**
		 * 读取远端的版本信息
		 */
		static private function readRemoteSwfVersion():void
		{
			var loader:URLLoader = new URLLoader;
			loader.load(new URLRequest(_remoteVersionUrl));

			/* handle io error by weak handler */
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:ErrorEvent):void{
				trace("[RemoteExecutableUpdater.readRemoteSwfVersion] fail to read remote swf version, error:"+event);
				_remoteVersion - 1;
				setTimeout(compareVersion, 1); /* 跳出栈, 利于gc */
			}, false, 0, true); /* 使用弱引用自动回收 */

			/* handle securtity error by weak handler */
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(event:ErrorEvent):void{
				trace("[RemoteExecutableUpdater.readRemoteSwfVersion] fail to read remote swf version, error:"+event);
				setTimeout(compareVersion, 1); /* 跳出栈, 利于gc */
				_remoteVersion - 1;
			}, false, 0, true); /* 使用弱引用自动回收 */

			/* handle complete event by weak handler */
			loader.addEventListener(Event.COMPLETE, function(event:Event):void{
				trace("[RemoteExecutableUpdater.readRemoteSwfVersion] complet, remote version data:"+loader.data);
				var dataStr:String = String(loader.data);
				var looksNotLikePureNumber:Boolean =  /[^\d\s\n\r]/.test(dataStr);
				if(looksNotLikePureNumber)
				{
					/* 认为远端数据是 json */
					try
					{
						var obj:Object = JSON.parse(dataStr) || {};
						_remoteVersion = parseInt(obj['version'] || obj['ver'] || obj['v'], 10) || 0;
						_remoteExecutableUrl = _remoteExecutableUrl || (obj['url'] || obj['uri'] || obj['swf'] || obj['client'])
					}
					catch(err:Error)
					{
						_remoteVersion = parseInt(dataStr, 10) || 0;
					}
				}
				else  
				{
					/* 远端的数据上上去象纯数值 */
					_remoteVersion = parseInt(dataStr, 10) || 0;
				}

				setTimeout(compareVersion, 1); /* 跳出栈, 利于gc */
			}, false, 0, true);
		}

		static private function compareVersion():void
		{
			trace("[RemoteExecutableUpdater.compareVersion] _localVersion:"+_localVersion+"; _localCachedVersion:"+_localCachedVersion+"; _remoteVersion:"+_remoteVersion);

			var newestVersion:int = Math.max(_localVersion, _localCachedVersion, _remoteVersion);

			if(newestVersion == _localVersion)
			{
				loadPreInstallExecutable();
			}
			else if(newestVersion == _localCachedVersion)
			{
				loadLocalCachedExecutable();
			}
			else
			{
				loadRemoteExecutable();
			}
		}

		/**
		 * 读取预装的 swf 文件
		 */
		private static function loadPreInstallExecutable():void
		{
			trace("[RemoteExecutableUpdater.loadPreInstallExecutable]");
			var ba:ByteArray = readLocalFile(_localExecutable);
			loader.loadBytes(ba, LOADER_CONTEXT);
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE,end);
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,end);
		}

		/**
		 * 读取本地缓存的 swf 文件
		 */
		private static function loadLocalCachedExecutable():void
		{
			trace("[RemoteExecutableUpdater.loadLocalCachedExecutable]");
			var ba:ByteArray = readLocalFile(File.applicationStorageDirectory.resolvePath(PATH_LOCAL_CACHE_EXECUTABLE));
			if(ba == null)
			{
				return loadPreInstallExecutable();
			}
			loader.loadBytes(ba, LOADER_CONTEXT);
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE,end);
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):void{
				trace("[RemoteExecutableUpdater.io error] fall back to pre install executable");
				try{
					loader.unloadAndStop(true);
				}catch(err:Error){}
				setTimeout(loadPreInstallExecutable, 1);
			}, false, 0, true);
		}

		/**
		 * 读取远程的 swf 文件
		 */
		private static function loadRemoteExecutable():void
		{
			trace("[RemoteExecutableUpdater.loadRemoteExecutable]");
			var streamer:URLStream = new URLStream;
			var handleStreamerError:Function = function(event:Event):void{
				trace("[RemoteExecutableUpdater.loadRemoteExecutable] streamer failed. error:"+event);
				setTimeout(loadLocalCachedExecutable, 1); /* fall back */
			}
			streamer.load(new URLRequest(_remoteExecutableUrl));
			streamer.addEventListener(ProgressEvent.PROGRESS, dispatcher.dispatchEvent, false, 0, true);
			streamer.addEventListener(IOErrorEvent.IO_ERROR, handleStreamerError, false, 0, true);
			streamer.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleStreamerError, false, 0, true);
			streamer.addEventListener(Event.COMPLETE, function(event:Event):void{
				var file:File = File.applicationStorageDirectory.resolvePath(PATH_LOCAL_CACHE_EXECUTABLE);
				var ba:ByteArray = new ByteArray;
				streamer.readBytes(ba);

				/* save swf to local cache */
				writeToStorageFile(PATH_LOCAL_CACHE_EXECUTABLE, ba);
				ba.clear();

				/* save version number to local cache */
				ba.writeUnsignedInt(_remoteVersion);
				writeToStorageFile(PATH_LOCAL_CACHE_VERSION,ba);
				ba.clear();

				setTimeout(loadLocalCachedExecutable, 1);
			}, false, 0, true);
		}

		/**
		 * 读取一个本地文件的二进制内容
		 * @param file
		 * @return
		 */
		static private function readLocalFile(file:File):ByteArray
		{
			var fileStream:FileStream=new FileStream();
			fileStream.open(file,"read");
			var ba:ByteArray=new ByteArray();
			fileStream.readBytes(ba);
			ba.position=0;
			fileStream.close();
			return ba;
		}


		static private function writeToStorageFile(path:String, ba:ByteArray):void
		{
			var file:File = File.applicationStorageDirectory.resolvePath(path);
			var fileStream:FileStream=new FileStream();
			fileStream.open(file,"write");
			fileStream.writeBytes(ba);
			fileStream.close();
		}

		/**
		 * 代理方法到  dispatcher
		 * @param type
		 * @param listener
		 * @param useCapture
		 * @param priority
		 * @param useWeakReference
		 */
		static public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
		{
			dispatcher.addEventListener(type, listener, useCapture, priority, useWeakReference);
		}

		/**
		 * 代理方法到  dispatcher
		 * @param type
		 * @param listener
		 * @param useCapture
		 */
		static public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void
		{
			dispatcher.removeEventListener(type, listener, useCapture);
		}
	}
}