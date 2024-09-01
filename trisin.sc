TriSin {

	classvar <voiceKeys;

	var <globalParams;
	var <voiceParams;
	var <voiceGroup;
	var <singleVoices;

	*initClass {
		voiceKeys = [ \1, \2, \3, \4, \5, \6, \7, \8];
		StartUp.add {
			var s = Server.default;

			s.waitForBoot {

				SynthDef("TriSin", {
					arg t_gate = 0,
					mRatio,
					cRatio,
					index,
					iScale,
					freq,
					phase,
					cutoff,
					resonance,
					cutoff_env,
					attack,
					release,
					iattack,
					irelease,
					cAtk,
					cRel,
					ciAtk,
					ciRel,
					amp,
					pan,
					freq_slew,
					amp_slew,
					pan_slew,
					bus;

					var car, mod, envelope, iEnv, filter, signal;
					var slewed_freq = freq.lag3(freq_slew);

					//amplitude envelope
					envelope = EnvGen.kr(
						envelope: Env(
							[0,1,0],
							times: [attack,release],
							curve: [cAtk, cRel])
						,
						gate: t_gate
					);

					//index of modulation
					iEnv = EnvGen.kr(
						Env(
							[index, index*iScale, index],
							times: [iattack, irelease],
							curve: [ciAtk, ciRel]
						),
						gate: t_gate
					);

					mod = SinOsc.ar(slewed_freq * mRatio, mul:slewed_freq * mRatio * iEnv);
					car = LFTri.ar(slewed_freq * cRatio + mod) * envelope * amp;

					filter = MoogFF.ar(
						in: car,
						freq: Select.kr(cutoff_env > 0, [cutoff, cutoff * envelope]),
						gain: resonance
					);

					signal = Pan2.ar(
						filter,
						pan.lag3(pan_slew)
					);

					Out.ar(bus,signal);
				}).add;
			} //waitForBoot
		} //StartUp
	} //initClass

	*new {
		^super.new.init;
	}

	init {
		var s = Server.default;

		voiceGroup = Group.new(s);

		globalParams = Dictionary.newFrom([
			\freq, 400,
			\mRatio, 1,
			\cRatio, 1,
			\index, 1,
			\iScale, 5,
			\phase, 0,
			\cutoff, 8000,
			\cutoff_env, 1,
			\resonance, 3,
			\attack, 0,
			\release, 0.4,
			\iattack, 0,
			\irelease, 0.4,
			\cAtk, 4,
			\cRel, (-4),
			\ciAtk, 4,
			\ciRel, (-4),
			\amp, 0.5,
			\pan, 0,
			\freq_slew, 0,
			\amp_slew, 0.05,
			\pan_slew, 0.5,
			\bus, 0;
		]);
		singleVoices = Dictionary.new;
		voiceParams = Dictionary.new;
		voiceKeys.do({
			arg voiceKey;
			singleVoices[voiceKey] = Group.new(voiceGroup);
			voiceParams[voiceKey] = Dictionary.newFrom(globalParams);
		});
	}

	playVoice {
		arg voiceKey, freq;
		if(singleVoices[voiceKey].isPlaying, {
			voiceParams[voiceKey][\freq] = freq;
			singleVoices[voiceKey].set(\freq, freq);
			singleVoices[voiceKey].set(\t_gate, 1);
		},{
			voiceParams[voiceKey][\freq] = freq;
			Synth.new("TriSin", voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
			singleVoices[voiceKey].set(\t_gate, 1);
			NodeWatcher.register(singleVoices[voiceKey],true);
		});
	}

	trigger {
		arg voiceKey, freq;
		if(
			voiceKey == 'all', {
				voiceKeys.do({
					arg vK;
					this.playVoice(vK, freq);
				});
			},
			{
				this.playVoice(voiceKey, freq);
			}
		);
	}

	adjustVoice {
		arg voiceKey, paramKey, paramValue;
		singleVoices[voiceKey].set(paramKey, paramValue);
		voiceParams[voiceKey][paramKey] = paramValue
	}

	setParam {
		arg voiceKey, paramKey, paramValue;
		if(
			voiceKey == 'all', {
				voiceKeys.do({
					arg vK;
					this.adjustVoice(vK, paramKey, paramValue);
				});
			},
			{
				this.adjustVoice(voiceKey, paramKey, paramValue);
			}
		);
	}

	freeAllNotes {
		voiceGroup.set(\stopGate, -1.05);
	}

	free {
		voiceGroup.free;
	}

}