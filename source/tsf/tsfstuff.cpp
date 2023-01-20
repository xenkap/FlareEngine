#define TSF_IMPLEMENTATION
#include "tsf.h"

tsf *load_filename(const char* path)
{
	tsf *g_TinySoundFont = tsf_load_filename(path);
	if (!g_TinySoundFont)
	{
		fprintf(stderr, "Could not load SoundFont\n");
		return NULL;
	}
	return g_TinySoundFont;
}

void set_output(tsf *g_TinySoundFont)
{
	tsf_set_output(g_TinySoundFont, TSF_MONO, 48000, 0);
}

int note_on(tsf *g_TinySoundFont, int preset_index, int key, float vel)
{
	return tsf_note_on(g_TinySoundFont, preset_index, key, vel);
}

short *render_short(tsf *g_TinySoundFont, int samples)
{
	short *sndData = new short[samples];
	tsf_render_short(g_TinySoundFont, sndData, samples, 0);
	return sndData;
}

short *loadToBuffer(tsf *g_TinySoundFont, int samples, int preset_index, int key, float vel, float tuning = 0.0)
{
	tsf *copy = tsf_copy(g_TinySoundFont);
	tsf_channel_set_tuning(copy, 0, tuning);
	tsf_note_on(copy, preset_index, key, vel);
	short* data = render_short(copy, samples);
	tsf_close(copy);
	return data;
}

int preset_count(tsf *g_TinySoundFont)
{
	return tsf_get_presetcount(g_TinySoundFont);
}

void clearSounds(tsf *g_TinySoundFont)
{
	tsf_reset(g_TinySoundFont);
}

void cleanup(tsf *g_TinySoundFont)
{
	tsf_close(g_TinySoundFont);
}
