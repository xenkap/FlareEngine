import sys.thread.Mutex;
import cpp.Native;
import haxe.Json;
import sys.FileSystem;
import cpp.NativeArray;
import Song.SwagSong;
import cpp.Star;
import cpp.Pointer;
import sys.io.File;
import flixel.util.FlxDestroyUtil;
import flixel.group.FlxGroup.FlxTypedGroup;
import TinySoundFont.TSF;
import cpp.ConstCharStar;
import cpp.Int16;
import cpp.RawPointer;
import flixel.system.FlxSound;
import haxe.io.Bytes;
import openfl.media.Sound;
import openfl.utils.ByteArray;

using StringTools;

class SoundFontThing
{
	var tsf:RawPointer<TSF>;

	public var sounds:FlxTypedGroup<FlxSound> = new FlxTypedGroup<FlxSound>();
	public var globalVolume:Float = 1.0;

	public var presetCount(default, null):Int;

	public function new(path:String)
	{
		tsf = TinySoundFont.load_filename(path);

		if (tsf == null)
		{
			trace("NO SOUNDFONT FOUND. USING DEFAULT.");
			tsf = TinySoundFont.load_filename("assets/soundfonts/default.sf2");
			if (tsf == null)
			{
				trace("DEFAULT SOUNDFONT MISSING!");
			}
		}

		TinySoundFont.set_output(tsf);
		presetCount = TinySoundFont.preset_count(tsf);
	}

	public function getBytes(length:Float, preset_index:Int, key:Int, vel:Float, tuning:Float = 0.0):Array<Int16>
	{
		if (tsf == null)
		{
			trace("NOT PLAYING. NO SOUNDFONT.");
			return null;
		}

		var sampleCount:Int = Math.round(48000 * length);
		var indexToPlay = (preset_index < presetCount ? preset_index : 0);
		var dataShort = TinySoundFont.loadToBuffer(tsf, sampleCount, indexToPlay, key, vel, tuning);
		var dataArray:Array<Int16> = dataShort.toUnmanagedArray(sampleCount);

		// dataShort.destroyArray();

		return dataArray;
	}

	// public function getBytesNote(note:Note, vol:Float = 1.0):Array<Int16>
	// {
	// 	if (note == null)
	// 		return null;
	// 	if (note.notePreset < 0)
	// 		return null;
	// 	if (note.isSustainNote)
	// 		return null;
	// 	var volume = note.noteVolume * vol;
	// 	return getBytes(getTime(note), note.notePreset, note.notePitch, volume);
	// }

	public static function getTime(note:Note)
	{
		var time:Float;
		if (note.noteLength > 0)
			time = (note.noteLength + stepCrochet()) / 1000;
		else if (note.sustainLength > 0)
			time = (note.sustainLength + stepCrochet()) / 1000;
		else
			time = stepCrochet() / 1000;
		return time;
	}

	public function render(length:Float, preset_index:Int, key:Int, vel:Float):FlxSound
	{
		if (tsf == null)
		{
			trace("NOT PLAYING. NO SOUNDFONT.");
			return null;
		}

		var sampleCount:Int = Math.round(48000 * length);
		var dataShort = TinySoundFont.loadToBuffer(tsf, sampleCount, preset_index, key, vel);
		var dataArray:Array<Int16> = dataShort.toUnmanagedArray(sampleCount);

		// var bytes:Bytes = Bytes.alloc(sampleCount * 2);
		// for (i in 0...dataArray.length)
		// {
		// 	bytes.setUInt16(i * 2, dataArray[i]);
		// }

		var bytes:Bytes = Bytes.alloc(sampleCount * 2 * 2);
		for (i in 0...dataArray.length)
		{
			bytes.setUInt16(i * 4, dataArray[i]);
			bytes.setUInt16(i * 4 + 2, dataArray[i]);
		}

		dataShort.destroyArray();

		var byteData = ByteArray.fromBytes(bytes);

		var snd = new Sound();
		snd.loadPCMFromByteArray(byteData, sampleCount, "short", true, 48000);

		var finalSound = new FlxSound().loadEmbedded(snd, false, true);
		finalSound.volume = globalVolume;
		sounds.add(finalSound);

		return finalSound;
	}

	public function renderNote(note:Note, vol:Float = 1.0):FlxSound
	{
		if (note == null)
			return null;

		if (note.notePreset < 0)
			return null;

		if (note.isSustainNote)
			return null;

		var volume = note.noteVolume * vol;

		return render(getTime(note), (note.notePreset < presetCount ? note.notePreset : 0), note.notePitch, volume);
	}

	public function play(length:Float, preset_index:Int, key:Int, vel:Float)
	{
		var finalSound = render(length, preset_index, key, vel);
		if (finalSound != null)
			sounds.add(finalSound.play());
	}

	public function playNote(note:Note, vol:Float = 1.0)
	{
		var finalSound = renderNote(note, vol);
		if (finalSound != null)
			sounds.add(finalSound.play());
	}

	public function refreshVolumes()
	{
		sounds.forEachAlive(function(snd)
		{
			snd.volume = globalVolume;
		});
	}

	public function destroy()
	{
		if (tsf == null)
			return;
		sounds = FlxDestroyUtil.destroy(sounds);
		TinySoundFont.cleanup(tsf);
		tsf = null;
	}

	public function stopSounds()
	{
		sounds.forEachAlive(function(snd)
		{
			snd.stop();
		});
	}

	public function pauseSounds()
	{
		sounds.forEachAlive(function(snd)
		{
			snd.pause();
		});
	}

	public function resumeSounds()
	{
		sounds.forEachAlive(function(snd)
		{
			snd.resume();
		});
	}

	public static function songToBytes(song:SwagSong, songLength:Float, stereo:Bool = false)
	{
		var voiceTime:Int = Math.ceil(songLength / 1000 * 48000 + 48000);
		var dadStr:Star<Int16> = Native.malloc(voiceTime * 2);
		var bfStr:Star<Int16> = Native.malloc(voiceTime * 2);
		var dadShort:Array<Int16> = Pointer.fromStar(dadStr).toUnmanagedArray(voiceTime);
		var bfShort:Array<Int16> = Pointer.fromStar(bfStr).toUnmanagedArray(voiceTime);
		var bfSound = new SoundFontThing("assets/soundfonts/" + song.player1 + ".sf2");
		var dadSound = new SoundFontThing("assets/soundfonts/" + song.player2 + ".sf2");
		var volumes = getVolumes(song);
		var pitchOffsets = getPitches(song);
		var dadVolume = volumes[0];
		var bfVolume = volumes[1];
		var dadPitchOffset = pitchOffsets[0];
		var bfPitchOffset = pitchOffsets[1];
		var samePlayers = (song.player1 == song.player2);

		for (i in 0...dadShort.length)
			dadShort[i] = 0;
		for (i in 0...bfShort.length)
			bfShort[i] = 0;

		for (section in song.notes)
		{
			for (note in section.sectionNotes)
			{
				if (note[1] == 8 || note[0] == null)
					continue;

				var sampleTime:Int = Math.floor(note[0] / 1000 * 48000);
				var length:Float = ((note[6] > 0 ? note[6] : note[2] > 0 ? note[2] : 0) + stepCrochet()) / 1000;
				var notePreset:Int = (note[4] != null ? note[4] : -1);
				var noteKey:Int = (note[3] != null ? note[3] : 60);
				var noteVel:Float = (note[5] != null ? note[5] : 1.0);

				if (notePreset == -1)
					continue;

				if (section.mustHitSection && note[1] <= 3 || !section.mustHitSection && note[1] > 3)
				{
					var bytes:Array<Int16> = bfSound.getBytes(length, notePreset, noteKey + bfPitchOffset, noteVel * bfVolume);
					append_short(bfShort, bytes, sampleTime, bytes.length);
					Pointer.ofArray(bytes).destroyArray();
				}
				else if (section.mustHitSection && note[1] > 3 || !section.mustHitSection && note[1] <= 3)
				{
					var bytes:Array<Int16> = dadSound.getBytes(length, notePreset, noteKey + dadPitchOffset, noteVel * dadVolume, samePlayers ? 0.1 : 0);
					append_short(dadShort, bytes, sampleTime, bytes.length);
					Pointer.ofArray(bytes).destroyArray();
				}
			}
		}

		bfSound.destroy();
		bfSound = null;
		dadSound.destroy();
		dadSound = null;

		if (!stereo)
		{
			return [dadShort, bfShort];
		}

		var bfStr2:Star<Int16> = Native.malloc(voiceTime * 2 * 2);
		var bfShort2:Array<Int16> = Pointer.fromStar(bfStr2).toUnmanagedArray(voiceTime * 2);
		var i = 0;
		while (i < bfShort.length)
		{
			bfShort2[i * 2 + 0] = bfShort[i];
			bfShort2[i * 2 + 1] = bfShort[i + 1];
			bfShort2[i * 2 + 2] = bfShort[i];
			bfShort2[i * 2 + 3] = bfShort[i + 1];
			i += 2;
		}
		Native.free(bfStr);

		var dadStr2:Star<Int16> = Native.malloc(voiceTime * 2 * 2);
		var dadShort2:Array<Int16> = Pointer.fromStar(dadStr2).toUnmanagedArray(voiceTime * 2);
		var i = 0;
		while (i < dadShort.length)
		{
			dadShort2[i * 2 + 0] = dadShort[i];
			dadShort2[i * 2 + 1] = dadShort[i + 1];
			dadShort2[i * 2 + 2] = dadShort[i];
			dadShort2[i * 2 + 3] = dadShort[i + 1];
			i += 2;
		}
		Native.free(dadStr);
		return [bfShort2, dadShort2];
	}

	public static function songToBytesSplit(song:SwagSong, songLength:Float, char:Int = 1, stereo:Bool = false)
	{
		var voiceTime:Int = Math.ceil(songLength / 1000 * 48000 + 48000);
		var bfStr:Star<Int16> = Native.malloc(voiceTime * 2);
		var bfShort:Array<Int16> = Pointer.fromStar(bfStr).toUnmanagedArray(voiceTime);
		var player:String = "";
		if (char == 1)
			player = song.player1;
		else
			player = song.player2;
		var bfSound = new SoundFontThing("assets/soundfonts/" + player + ".sf2");
		var volumes = getVolumes(song);
		var pitchOffsets = getPitches(song);
		var dadVolume = volumes[0];
		var bfVolume = volumes[1];
		var dadPitchOffset = pitchOffsets[0];
		var bfPitchOffset = pitchOffsets[1];
		var samePlayers = (song.player1 == song.player2);

		for (i in 0...bfShort.length)
			bfShort[i] = 0;

		for (section in song.notes)
		{
			for (note in section.sectionNotes)
			{
				if (note[1] == 8 || note[0] == null)
					continue;

				var sampleTime:Int = Math.floor(note[0] / 1000 * 48000);
				var length:Float = ((note[6] > 0 ? note[6] : note[2] > 0 ? note[2] : 0) + stepCrochet()) / 1000;
				var notePreset:Int = (note[4] != null ? note[4] : -1);
				var noteKey:Int = (note[3] != null ? note[3] : 60);
				var noteVel:Float = (note[5] != null ? note[5] : 1.0);

				if (notePreset == -1)
					continue;

				if (char == 1)
				{
					if (section.mustHitSection && note[1] <= 3 || !section.mustHitSection && note[1] > 3)
					{
						var bytes:Array<Int16> = bfSound.getBytes(length, notePreset, noteKey + bfPitchOffset, noteVel * bfVolume);
						append_short(bfShort, bytes, sampleTime, bytes.length);
						Pointer.ofArray(bytes).destroyArray();
					}
				}
				else
				{
					if (section.mustHitSection && note[1] > 3 || !section.mustHitSection && note[1] <= 3)
					{
						var bytes:Array<Int16> = bfSound.getBytes(length, notePreset, noteKey + dadPitchOffset, noteVel * dadVolume, samePlayers ? 0.1 : 0);
						append_short(bfShort, bytes, sampleTime, bytes.length);
						Pointer.ofArray(bytes).destroyArray();
					}
				}
			}
		}

		bfSound.destroy();
		bfSound = null;

		if (!stereo)
		{
			return bfShort;
		}

		var bfStr2:Star<Int16> = Native.malloc(voiceTime * 2 * 2);
		var bfShort2:Array<Int16> = Pointer.fromStar(bfStr2).toUnmanagedArray(voiceTime * 2);
		var i = 0;
		while (i < bfShort.length)
		{
			bfShort2[i * 2 + 0] = bfShort[i];
			bfShort2[i * 2 + 1] = bfShort[i + 1];
			bfShort2[i * 2 + 2] = bfShort[i];
			bfShort2[i * 2 + 3] = bfShort[i + 1];
			i += 2;
		}
		Native.free(bfStr);
		return bfShort2;
	}

	static function getVolumes(SONG:SwagSong)
	{
		var theSong = SONG.song.split("_")[0];
		var bfVolume = SONG.vocalVolume;
		var dadVolume = SONG.vocalVolume;
		if (FileSystem.exists(Paths.json(theSong + '/' + "volumes")))
		{
			var songVolJson:String = File.getContent(Paths.json(theSong + '/' + "volumes")).trim();
			var songVolumes:SongVolumes = Json.parse(songVolJson);

			if (songVolumes != null)
			{
				var volumesToChoose:Array<CharVolume>;

				if (SONG.song.endsWith("_Hard"))
				{
					volumesToChoose = songVolumes.hard;
				}
				else if (SONG.song.endsWith("_Easy"))
				{
					volumesToChoose = songVolumes.easy;
				}
				else
				{
					volumesToChoose = songVolumes.normal;
				}

				if (volumesToChoose != null)
				{
					var map = new Map<String, Float>();

					for (array in volumesToChoose)
					{
						map[array.char] = array.volume;
					}

					if (map[SONG.player1] != null)
					{
						bfVolume *= map[SONG.player1];
						bfVolume = Math.min(bfVolume, 1.0);
						trace("bfVolume " + bfVolume);
					}
					if (map[SONG.player2] != null)
					{
						dadVolume *= map[SONG.player2];
						dadVolume = Math.min(dadVolume, 1.0);
						trace("dadVolume  " + dadVolume);
					}
				}
			}
		}

		return [dadVolume, bfVolume];
	}

	static function getPitches(SONG:SwagSong)
	{
		var theSong = SONG.song.split("_")[0];
		var bfPitch = 0;
		var dadPitch = 0;
		if (FileSystem.exists(Paths.json(theSong + '/' + "pitches")))
		{
			var songPitchJson:String = File.getContent(Paths.json(theSong + '/' + "pitches")).trim();
			var songPitches:SongPitches = Json.parse(songPitchJson);

			if (songPitches != null)
			{
				var pitchesToChoose:Array<CharPitch>;

				if (SONG.song.endsWith("_Hard"))
				{
					pitchesToChoose = songPitches.hard;
				}
				else if (SONG.song.endsWith("_Easy"))
				{
					pitchesToChoose = songPitches.easy;
				}
				else
				{
					pitchesToChoose = songPitches.normal;
				}

				if (pitchesToChoose != null)
				{
					var map = new Map<String, Int>();

					for (array in pitchesToChoose)
					{
						map[array.char] = array.pitchOffset;
					}

					if (map[SONG.player1] != null)
					{
						bfPitch = map[SONG.player1];
						trace("bfPitch " + bfPitch);
					}
					if (map[SONG.player2] != null)
					{
						dadPitch = map[SONG.player2];
						trace("dadVolume  " + dadPitch);
					}
				}
			}
		}

		return [dadPitch, bfPitch];
	}

	static inline function stepCrochet()
	{
		return ((60 / PlayState.SONG.bpm) * 1000) / 4;
	}

	static inline function fade(data:Int16, index:Int, length:Int):Int16
	{
		if (length < 1000)
			return 0;

		var stop:Int = 440;

		if (index < stop)
		{
			return Std.int((index / stop) * data);
		}
		else if (index > length - stop)
		{
			return Std.int(((length - index) / stop) * data);
		}
		else
		{
			return data;
		}
	}

	static function append_short(target:Array<Int16>, src:Array<Int16>, index:Int, length:Int)
	{
		for (i in 0...length)
		{
			if (target[index + i] == 0)
				target[index + i] = fade(src[i], i, length);
			else
				target[index + i] = Std.int((target[index + i] + fade(src[i], i, length)) / Math.sqrt(2));
		}
	}

	public static function rawPCMtoWAV(shortArr:Array<Int16>, stereo:Bool = false)
	{
		var wav = BytesThing.alloc(shortArr.length * 2 + 44);
		wav.fill(0, wav.length, 0);
		// wav.blit(44, rawBytes, 0, rawBytes.length);
		wav.setInt32(0, 1179011410);
		wav.setInt32(4, wav.length - 8);
		wav.setInt32(8, 1163280727);
		wav.setInt32(12, 544501094);
		wav.setInt32(16, 16);
		wav.setUInt16(20, 1);
		if (stereo)
		{
			wav.setUInt16(22, 2);
			wav.setInt32(24, 48000);
			wav.setInt32(28, 192000);
			wav.setUInt16(32, 4);
		}
		else
		{
			wav.setUInt16(22, 1);
			wav.setInt32(24, 48000);
			wav.setInt32(28, 96000);
			wav.setUInt16(32, 2);
		}
		wav.setUInt16(34, 16);
		wav.setInt32(36, 1635017060);
		wav.setInt32(40, shortArr.length * 2);
		for (i in 0...shortArr.length)
		{
			wav.setUInt16(i * 2 + 44, shortArr[i]);
		}
		return wav;
	}

	public static function songGen()
	{
		if (PlayState.overridePlayer1 != "")
			PlayState.SONG.player1 = PlayState.overridePlayer1;
		if (PlayState.overridePlayer2 != "")
			PlayState.SONG.player2 = PlayState.overridePlayer2;
		var songLength:Float = 0;
		for (section in PlayState.SONG.notes)
		{
			for (note in section.sectionNotes)
			{
				var length:Float = note[0] + ((note[6] > 0 ? note[6] : note[2] > 0 ? note[2] : 0) + stepCrochet());
				songLength = Math.max(length, songLength);
			}
		}
		var vocalBytes = songToBytes(PlayState.SONG, songLength);
		if (!FileSystem.isDirectory("assets/temp"))
			FileSystem.createDirectory("assets/temp");
		var dadWav = SoundFontThing.rawPCMtoWAV(vocalBytes[0]);
		var bfWav = SoundFontThing.rawPCMtoWAV(vocalBytes[1]);
		File.saveBytes("assets/temp/dad.wav", dadWav);
		File.saveBytes("assets/temp/bf.wav", bfWav);
		Pointer.ofArray(vocalBytes[0]).destroyArray();
		Pointer.ofArray(vocalBytes[1]).destroyArray();
		vocalBytes = null;
		dadWav.destroy();
		bfWav.destroy();
		PlayState.p1WriteDone = PlayState.p2WriteDone = true;
	}

	public static function asyncSongGen()
	{
		PlayState.p1WriteDone = PlayState.p2WriteDone = false;
		if (PlayState.overridePlayer1 != "")
			PlayState.SONG.player1 = PlayState.overridePlayer1;
		if (PlayState.overridePlayer2 != "")
			PlayState.SONG.player2 = PlayState.overridePlayer2;
		sys.thread.Thread.create(() ->
		{
			var songLength:Float = 0;
			for (section in PlayState.SONG.notes)
			{
				for (note in section.sectionNotes)
				{
					var length:Float = note[0] + ((note[6] > 0 ? note[6] : note[2] > 0 ? note[2] : 0) + stepCrochet());
					songLength = Math.max(length, songLength);
				}
			}

			var mutex = new Mutex();

			sys.thread.Thread.create(() ->
			{
				var vocalBytes = SoundFontThing.songToBytesSplit(PlayState.SONG, songLength, 1);
				mutex.acquire();
				if (!FileSystem.isDirectory("assets/temp"))
					FileSystem.createDirectory("assets/temp");
				mutex.release();
				var wav = SoundFontThing.rawPCMtoWAV(vocalBytes);
				File.saveBytes("assets/temp/bf.wav", wav);
				Pointer.ofArray(vocalBytes).destroyArray();
				vocalBytes = null;
				wav.destroy();
				PlayState.p1WriteDone = true;
			});

			var vocalBytes = SoundFontThing.songToBytesSplit(PlayState.SONG, songLength, 2);
			mutex.acquire();
			if (!FileSystem.isDirectory("assets/temp"))
				FileSystem.createDirectory("assets/temp");
			mutex.release();
			var wav = SoundFontThing.rawPCMtoWAV(vocalBytes);
			File.saveBytes("assets/temp/dad.wav", wav);
			Pointer.ofArray(vocalBytes).destroyArray();
			vocalBytes = null;
			wav.destroy();
			PlayState.p2WriteDone = true;
		});
	}
}

typedef SongVolumes =
{
	var easy:Array<CharVolume>;
	var normal:Array<CharVolume>;
	var hard:Array<CharVolume>;
}

typedef CharVolume =
{
	var char:String;
	var volume:Float;
}

typedef SongPitches =
{
	var easy:Array<CharPitch>;
	var normal:Array<CharPitch>;
	var hard:Array<CharPitch>;
}

typedef CharPitch =
{
	var char:String;
	var pitchOffset:Int;
}