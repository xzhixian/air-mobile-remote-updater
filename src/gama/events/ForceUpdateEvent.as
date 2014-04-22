package gama.events
{
	import flash.events.Event;

	public class ForceUpdateEvent extends Event
	{
		public var updateUrL:String ;

		static public const NEED_THROUGHLY_UPDATE:String = "needThroughlyUpdate";

		public function ForceUpdateEvent(url:String)
		{
			super(NEED_THROUGHLY_UPDATE, false, false);
			updateUrL = url;
		}
	}
}