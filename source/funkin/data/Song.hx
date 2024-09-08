package funkin.data;

#if moonchart
import moonchart.formats.fnf.legacy.FNFPsych as SupportedFormat;
import moonchart.formats.BasicFormat;
import moonchart.backend.FormatDetector;
#end

import funkin.states.LoadingState;
import funkin.states.PlayState;
import funkin.data.Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

using StringTools;
#if sys
import sys.FileSystem;
import sys.io.File;
#end


typedef SwagSong =
{
	@:optional var song:String;
	@:optional var bpm:Float;
	@:optional var speed:Float;
	@:optional var notes:Array<SwagSection>;
	@:optional var events:Array<Array<Dynamic>>;
	
	@:optional var needsVoices:Bool;
	@:optional var validScore:Bool;

	@:optional var player1:String;
	@:optional var player2:String;
	@:optional var player3:String;
	@:optional var gfVersion:String;
	@:optional var stage:String;
    @:optional var hudSkin:String;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;

	@:optional var extraTracks:Array<String>;
	@:optional var info:Array<String>;
	@:optional var metadata:SongCreditdata;
}

typedef SongCreditdata = // beacuse SongMetadata is stolen
{
	?artist:String,
	?charter:String,
	?modcharter:String,
	?extraInfo:Array<String>,
}

class Song
{
	public var song:String;
	public var bpm:Float;
	public var speed:Float = 1;
	public var notes:Array<SwagSection>;
	public var events:Array<Array<Dynamic>>;
	
	public var needsVoices:Bool = true;
	public var arrowSkin:Null<String> = null;
	public var splashSkin:Null<String> = null;

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var stage:String;

	public var extraTracks:Array<String> = [];

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static function getCharts(metadata:SongMetadata):Array<String>
	{
		Paths.currentModDirectory = metadata.folder;
		final songName = Paths.formatToSongPath(metadata.songName);
		final charts = new haxe.ds.StringMap();
		
		function processFileName(unprocessedName:String)
		{		
			var fileName:String = unprocessedName.toLowerCase();
            if (fileName == '$songName.json'){
				charts.set("normal", true);
				return;
			}
			else if (!fileName.startsWith('$songName-') || !fileName.endsWith('.json')){
				return;
			}

			final extension_dot = songName.length + 1;
			charts.set(fileName.substr(extension_dot, fileName.length - extension_dot - 5), true);
		}


		if (metadata.folder == "")
		{
			#if PE_MOD_COMPATIBILITY
			Paths.iterateDirectory(Paths.getPreloadPath('data/$songName/'), processFileName);
			#end
			Paths.iterateDirectory(Paths.getPreloadPath('songs/$songName/'), processFileName);
		}
		#if MODS_ALLOWED
		else
		{
			#if PE_MOD_COMPATIBILITY
			Paths.iterateDirectory(Paths.mods('${metadata.folder}/data/$songName/'), processFileName);
			#end
			Paths.iterateDirectory(Paths.mods('${metadata.folder}/songs/$songName/'), processFileName);
		}
		#end

		return [for (name in charts.keys()) name];
	}

	public static function loadFromJson(jsonInput:String, folder:String):Null<SwagSong>
	{
		var path:String = Paths.formatToSongPath(folder) + '/' + Paths.formatToSongPath(jsonInput) + '.json';
		var rawJson:Null<String> = Paths.text('songs/$path', false);
		
		#if PE_MOD_COMPATIBILITY
		if (rawJson == null)
			rawJson = Paths.text('data/$path', false);
		#end

		if (rawJson == null){
			trace('song JSON file not found: $path');
			return null;
		}

		rawJson = rawJson.trim();

		// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		while (!rawJson.endsWith("}"))
			rawJson = rawJson.substr(0, rawJson.length - 1);

		var songJson:SwagSong = parseJSONshit(rawJson);
		// if(jsonInput != 'events') Stage.StageData.loadDirectory(songJson);
		onLoadJson(songJson);

		return songJson;
	}

	/** sanitize/update json values to a valid format**/
	private static function onLoadJson(songJson:Dynamic)
	{
		if(songJson.gfVersion == null){
			if (songJson.player3 != null){
				songJson.gfVersion = songJson.player3;
				songJson.player3 = null;
			}
			else
				songJson.gfVersion = "gf";
		}

		if (songJson.extraTracks == null){
			songJson.extraTracks = [];
		}

		if(songJson.events == null){
			songJson.events = [];
			
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				var i:Int = 0;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if (note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		if(songJson.hudSkin==null)
			songJson.hudSkin = 'default';

		return songJson;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;
		return swagShit;
	}

	static public function loadSong(metadata:SongMetadata, ?difficulty:String, ?difficultyIdx:Int = 1) {
		Paths.currentModDirectory = metadata.folder;

		var songLowercase:String = Paths.formatToSongPath(metadata.songName);
		var diffSuffix:String;

		if (difficulty == null || difficulty == "" || difficulty == "normal"){
			difficulty = 'normal';
			diffSuffix = '';
		}else{
			difficulty = difficulty.trim().toLowerCase();
			diffSuffix = '-$difficulty';
		}
		
		var chartFileName:String = songLowercase + diffSuffix;
		
		if (Main.showDebugTraces)
			trace('playSong', Paths.currentModDirectory, chartFileName);
		
		#if moonchart
		var chartDirPath:String = 'content/base-game/songs/$songLowercase/';
		var chartFilePath:String = chartDirPath + chartFileName + '.json';

		var format = FormatDetector.findFormat([chartFilePath]);
/*         if(format == null){
            trace("THERES NO FUCKING CHART HERE??? WHAT!!!");
            // find a good way to notify the user there's no valid chart lol
            return;
        } */
		var formatInfo = FormatDetector.getFormatData(format);

		var SONG:SwagSong = switch(format) {
			case "FNF_LEGACY_PSYCH" | "FNF_LEGACY":
				trace('Chart format $format is good to be read ^.^');
				Song.loadFromJson(chartFileName, songLowercase);

			default:
				trace('Converting from format $format!');
				
				var chart:moonchart.formats.BasicFormat<{}, {}>;
				chart = Type.createInstance(formatInfo.handler, []);
				chart = chart.fromFile(chartFilePath);
				
				var converted = new SupportedFormat().fromFormat(chart, difficulty);
				onLoadJson(converted);
		}
		#else
		var SONG:SwagSong = Song.loadFromJson(songLowercase + diffSuffix, songLowercase);
		#end

		PlayState.SONG = SONG;
		PlayState.difficulty = difficultyIdx;
		PlayState.difficultyName = difficulty;
		PlayState.isStoryMode = false;	
	}

	static public function switchToPlayState()
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;

		if (FlxG.keys.pressed.SHIFT)
			LoadingState.loadAndSwitchState(new funkin.states.editors.ChartingState());
		else
			LoadingState.loadAndSwitchState(new PlayState());	
	}

	static public function playSong(metadata:SongMetadata, ?difficulty:String, ?difficultyIdx:Int = 1)
	{
		loadSong(metadata, difficulty, difficultyIdx);
		switchToPlayState();
	} 
}

@:structInit
class SongMetadata
{
	public var songName:String = '';
	public var folder:String = '';
	public var charts(get, null):Array<String>;
	function get_charts()
		return (charts == null) ? charts = Song.getCharts(this) : charts;

	public function new(songName:String, ?folder:String = '')
	{
		this.songName = songName;
		this.folder = folder != null ? folder : '';
	}

	public function play(?difficultyName:String = ''){
        if(charts.contains(difficultyName))
			return Song.playSong(this, difficultyName, charts.indexOf(difficultyName));
    
        trace("Attempt to play null difficulty: " + difficultyName);
    }

	public function toString()
		return '$folder:$songName';
}