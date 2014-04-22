package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;  
	import flash.filesystem.File;
	
	import gama.RemoteExecutableUpdater;
	
	public class RemoteExecutableDemo extends Sprite
	{
		public function RemoteExecutableDemo()
		{
			addEventListener(Event.ENTER_FRAME, init);
		}
		
		public function init(evt:Event):void
		{
			removeEventListener(Event.ENTER_FRAME, init);
			RemoteExecutableUpdater.start(77, File.applicationDirectory.resolvePath("data/local.swf"), "http://mdthai.b0.upaiyun.com/reu.sample.json");
			RemoteExecutableUpdater.addEventListener(Event.COMPLETE, handleREUComplete);
			RemoteExecutableUpdater.addEventListener(ProgressEvent.PROGRESS, handleREUProgress);
			RemoteExecutableUpdater.addEventListener(IOErrorEvent.IO_ERROR, handleREUError)
			RemoteExecutableUpdater.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleREUError);
		}
		
		private function handleREUProgress(event:ProgressEvent):void
		{
			trace("[handleREUProgress]"+event.bytesLoaded+"/"+event.bytesTotal);
		}
		
		
		private function handleREUError(event:Event):void
		{
			trace("[handleREUError]");
		}
		
		private function handleREUComplete(event:Event):void
		{
			trace("[handleREUComplete]");
			addChild(RemoteExecutableUpdater.loader);
		}		

	}
}