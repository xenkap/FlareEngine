import cpp.Star;
import cpp.ConstCharStar;
import cpp.ConstPointer;
import cpp.Float32;
import cpp.Int16;
import cpp.NativeArray;
import cpp.Pointer;
import cpp.RawPointer;

@:buildXml('<include name="../../../../source/tsf/TinySoundfontBuild.xml" />')
@:include("tsf.h")
@:keep
@:unreflective
@:structAccess
@:native("tsf")
extern class TSF {}

@:buildXml('<include name="../../../../source/tsf/TinySoundfontBuild.xml" />')
@:include("tsfstuff.cpp")
@:keep
@:unreflective
@:native("TinySoundFont*")
extern class TinySoundFont
{
	@:native("load_filename") public static function load_filename(path:ConstCharStar):RawPointer<TSF>;
	@:native("set_output") public static function set_output(tsf:RawPointer<TSF>):Void;
	@:native("note_on") public static function note_on(tsf:RawPointer<TSF>, preset_index:Int, key:Int, vel:Float):Int;
	@:native("render_short") public static function render_short(tsf:RawPointer<TSF>, samples:Int):Pointer<Int16>;
	@:native("preset_count") public static function preset_count(tsf:RawPointer<TSF>):Int;
	@:native("cleanup") public static function cleanup(tsf:RawPointer<TSF>):Void;
	@:native("loadToBuffer") public static function loadToBuffer(tsf:RawPointer<TSF>, samples:Int, preset_index:Int, key:Int, vel:Float, tuning:Float = 0.0):Pointer<Int16>;
	@:native("clearSounds") public static function clearSounds(tsf:RawPointer<TSF>):Void;
}