(
Task(
	{
		//boot the SuperCollider server
		s.reboot;
		o = Server.default.options;
		o.outDevice_("Scarlett 4i4 USB");
		o.inDevice_("Scarlett 4i4 USB");
		o.memSize_(2.pow(21));
		s.latency_(0.5);
		//s.options.numWireBufs_(128);

		//wait
		s.waitForBoot(
			{

				//timer
				~timer = LinkClock.new(128/60);

				//buffer & bus allocation
				~bf = Buffer.alloc(Server.default,4096,2);
				~fb = Bus.audio(Server.default,2);
				~pbp_bufs = Array.fill(16,{arg i; i});
				~pbp_seqs = PatternProxy(Pseq(~pbp_bufs, inf)).asStream;
				~delBuf = Buffer.alloc(s,s.sampleRate*(~timer.beatDur*512),1);
				~micBus = Bus.audio(s,1);
				~ptrBus = Bus.audio(s,1);

				//samples go here! Change PathName to point to your own folder(s) of samples
				//TIP: you can drag and drop a folder right into this window, and its pathname will show up where you drop it
				d = Dictionary.new;
				d.add(\l ->
					PathName(thisProcess.nowExecutingPath.dirname++"/samples/808/").entries.collect({
						arg sf;
						Buffer.read(s, sf.fullPath);
					});
				);
				d.add(\n ->
					PathName(thisProcess.nowExecutingPath.dirname++"/samples/PBP/").entries.collect({
						arg sf;
						Buffer.readChannel(s, sf.fullPath, channels: [0,1]);
					});
				);
				s.sync;

				//Create some LFOs for modulation
				~panLFO=Array.fill(16,{});
				~cutoffLFO=Array.fill(16,{});
				~resLFO=Array.fill(16,{});
				~indexLFO=Array.fill(16,{});
				8.do({
					arg i;
					~panLFO[i] = Ndef(
						i.asSymbol,
						{
							LFTri.kr(1/(rrand(2,16))).range(-1,1)
						}
					);
					~cutoffLFO[i] = Ndef(
						(i+8).asSymbol,
						{
							LFTri.kr(1/(rrand(2,16))).range(500,15000)
						}
					);
					~resLFO[i] = Ndef(
						(i+16).asSymbol,
						{
							LFTri.kr(1/(rrand(2,16))).range(0,2)
						}
					);
					~indexLFO[i] = Ndef(
						(i+24).asSymbol,
						{
							LFTri.kr(1/(rrand(2,16))).range(-3,3)
						}
					);
				});

				//Define synth sounds
				x = Array.fill(64,{});
				4.do({
					arg j;
					x.put(j,TriSin.new);
					x.put(j+4,Ringer.new);
					x.put(j+8,TriSin.new);
					x.put(j+12,Ringer.new);
				});
				16.do({
					arg j;
					x.put(j+48,OneShot.new);
					x[j+48].setParam('all',\bus,~fb.index)
				});
				4.do({
					arg j;
					8.do({
						arg i;
						if(
							j < 2,
							{
								x[j].setParam((i+1).asSymbol,\attack,rrand(2.0,10.0));
								x[j].setParam((i+1).asSymbol,\release,rrand(2.0,10.0));
							},
							{
								x[j].setParam((i+1).asSymbol,\attack,rrand(0,1.0));
								x[j].setParam((i+1).asSymbol,\release,rrand(0.5,2.0));
							}
						);
						x[j].setParam((i+1).asSymbol,\modnum,rrand(1,4));
						x[j].setParam((i+1).asSymbol,\modeno,rrand(1,4));
						x[j].setParam((i+1).asSymbol,\cutoff_env,[0,1].choose);
						x[j].setParam((i+1).asSymbol,\freq_slew,[0,0.1].choose);
						x[j].setParam((i+1).asSymbol,\pan_slew,[0.1,20.0].choose);
						x[j].setParam((i+1).asSymbol,\bus,b);
						x[j].setParam((i+1).asSymbol,\pan,~panLFO[i]);
						x[j].setParam((i+1).asSymbol,\cutoff,~cutoffLFO[i]);
						x[j].setParam((i+1).asSymbol,\resonance,~resLFO[i]);
						x[j].setParam((i+1).asSymbol,\index,~indexLFO[i]);
						x[j+8].setParam((i+1).asSymbol,\attack,rrand(0,1.0));
						x[j+8].setParam((i+1).asSymbol,\release,rrand(0.5,2.0));
						x[j+8].setParam((i+1).asSymbol,\modnum,rrand(1,4));
						x[j+8].setParam((i+1).asSymbol,\modeno,rrand(1,4));
						x[j+8].setParam((i+1).asSymbol,\cutoff_env,[0,1].choose);
						x[j+8].setParam((i+1).asSymbol,\freq_slew,[0,0.1].choose);
						x[j+8].setParam((i+1).asSymbol,\pan_slew,[0.1,20.0].choose);
						x[j+8].setParam((i+1).asSymbol,\bus,b);
						x[j+4].setParam((i+1).asSymbol,\pan,~panLFO[i]);
						x[j+8].setParam((i+1).asSymbol,\pan,~panLFO[i]);
						x[j+12].setParam((i+1).asSymbol,\index,0.42);
						x[j+12].setParam((i+1).asSymbol,\pan,~panLFO[i]);
						x[j+8].setParam((i+1).asSymbol,\cutoff,~cutoffLFO[i]);
						x[j+8].setParam((i+1).asSymbol,\resonance,~resLFO[i]);
						x[j+8].setParam((i+1).asSymbol,\index,~indexLFO[i]);
					});
				});

				//sampler
				Task({
					SynthDef(\PlayBufPlayer, {
						arg out=0,
						bufnum=0,
						rate=1,
						start=0,
						end=1,
						t_trig=0,
						loops=1,
						amp=0.2,
						pan=0,
						rateSlew=0.1,
						panSlew=1,
						bus=~fb.index;
						var snd,
						snd2,
						pos,
						pos2,
						frames,
						duration,
						env,
						sig,
						startA,
						endA,
						startB,
						endB,
						crossfade,
						aOrB;
						aOrB=ToggleFF.kr(t_trig);
						startA=Latch.kr(start,aOrB);
						endA=Latch.kr(end,aOrB);
						startB=Latch.kr(start,1-aOrB);
						endB=Latch.kr(end,1-aOrB);
						crossfade=Lag.ar(K2A.ar(aOrB),0.1);
						rate=Lag.kr(rate,rateSlew)*BufRateScale.kr(bufnum);
						frames=BufFrames.kr(bufnum);
						duration=frames*(end-start)/rate.abs/s.sampleRate*loops;
						env=EnvGen.ar(
							Env.new(
								levels: [0,amp,amp,0],
								times: [0,duration-0.1,0.1],
							),
							gate:t_trig,
						);
						pos=Phasor.ar(
							trig:aOrB,
							rate:rate,
							start:(((rate>0)*startA)+((rate<0)*endA))*frames,
							end:(((rate>0)*endA)+((rate<0)*startA))*frames,
							resetPos:(((rate>0)*startA)+((rate<0)*endA))*frames,
						);
						snd=BufRd.ar(
							numChannels:2,
							bufnum:bufnum,
							phase:pos,
							interpolation:4,
						);
						pos2=Phasor.ar(
							trig:(1-aOrB),
							rate:rate,
							start:(((rate>0)*startB)+((rate<0)*endB))*frames,
							end:(((rate>0)*endB)+((rate<0)*startB))*frames,
							resetPos:(((rate>0)*startB)+((rate<0)*endB))*frames,
						);
						snd2=BufRd.ar(
							numChannels:2,
							bufnum:bufnum,
							phase:pos2,
							interpolation:4,
						);
						sig=Pan2.ar(
							MoogFF.ar(
								in:(crossfade*snd)+((1-crossfade)*snd2)*env,
								freq:\cutoff.kr(12000),
								gain:\resonance.kr(1)),
							pan
						);
						Out.ar(bus,sig)
					}).play(s,[\out,~fb.index]);
					s.sync;
					32.do(
						{
							arg i;
							if(
								i % 2 == 0,
								{
									x.put(16+i,Synth(\PlayBufPlayer,[\bufnum,d[\n][~pbp_seqs.next]]));
									x[16+i].set(\cutoff,15000,\resonance,0,\pan,-1,\start,0,\end,1,\loops,1,\amp,1,\bus,~fb.index)
								}
							)
						}
					);
				}).play;

				//mic
				SynthDef.new(\mic, {
					arg in=0,
					out=0,
					amp=1;
					var sig;
					sig=SoundIn.ar(in)*amp;
					Out.ar(out,sig);
				}).add;
				SynthDef(\ptr, {
					arg out=0,
					buf=0,
					rate=1;
					var sig;
					sig=Phasor.ar(0,BufRateScale.kr(buf)*rate,0,BufFrames.kr(buf));
					Out.ar(out, sig);
				}).add;
				SynthDef.new(\rec, {
					arg ptrIn=0,
					micIn=0,
					buf=0;
					var ptr,
					sig;
					ptr=In.ar(ptrIn,1);
					sig=In.ar(micIn,1);
					BufWr.ar(sig,buf,ptr);
				}).add;
				SynthDef(\gran, {
					arg amp = 0.5, buf = 0, out = 0,
					atk = 1, rel = 1, gate = 1,
					sync = 1, dens = 40,
					baseDur = 0.05, durRand = 1,
					rate = 1, rateRand = 1,
					pan = 0, panRand = 0,
					grainEnv = (-1), ptrBus = 0, ptrSampleDelay = 20000,
					ptrRandSamples = 5000, minPtrDelay = 1000;
					var sig, env, densCtrl, durCtrl, rateCtrl, panCtrl,
					ptr, ptrRand, totalDelay, maxGrainDur;
					env = EnvGen.kr(Env.asr(atk,1,rel), gate, doneAction: 2);
					densCtrl = Select.ar(sync, [Dust.ar(dens), Impulse.ar(dens)]);
					durCtrl = baseDur * LFNoise1.ar(100).exprange(1/durRand, durRand);
					rateCtrl = rate.lag3(0.5) * LFNoise1.ar(100).exprange(1/rateRand, rateRand);
					panCtrl = pan + LFNoise1.kr(100).bipolar(panRand);
					ptrRand = LFNoise1.ar(100).bipolar(ptrRandSamples);
					totalDelay = max(ptrSampleDelay - ptrRand, minPtrDelay);
					ptr = In.ar(ptrBus, 1);
					ptr = ptr - totalDelay;
					ptr = ptr / BufFrames.kr(buf);
					maxGrainDur = (totalDelay / rateCtrl) / SampleRate.ir;
					durCtrl = min(durCtrl, maxGrainDur);
					sig = GrainBuf.ar(
						2,
						densCtrl,
						durCtrl,
						buf,
						rateCtrl,
						ptr,
						4,
						panCtrl,
						grainEnv
					);
					sig = MoogFF.ar(
						sig * env * amp,
						freq: \cutoff.kr(12000),
						gain: \resonance.kr(1)
					);
					Out.ar(out, sig);
				}).add;
				s.sync;

				~micGrp=Group.new;
				~ptrGrp=Group.after(~micGrp);
				~recGrp=Group.after(~ptrGrp);
				~granGrp=Group.tail;
				~delMic=Synth(\mic,[\in,0,\out,~micBus,\amp,0],~micGrp);
				~inMic=2.collect(
					{
						arg i;
						Synth(\mic,[\in,0,\out,~fb.index+i,\amp,0],~micGrp);
					}
				);
				Synth(\ptr,[\buf,~delBuf,\out,~ptrBus],~ptrGrp);
				Synth(\rec,[\ptrIn,~ptrBus,\micIn,~micBus,\buf,~delBuf],~recGrp);

				//Carter's Delay
				~rates = [1/4,1/2,1,3/2,2].scramble;
				~durs = 15.collect({arg i; ~timer.beatDur*(i+1)}).scramble;
				~delays = 15.collect({arg i; s.sampleRate*(~timer.beatDur*(i+1))*8}).scramble;
				~g = 15.collect({
					arg n;
					Synth(\gran, [
						\amp, 0,
						\buf, ~delBuf,
						\out, ~fb.index,
						\atk, 1,
						\rel, 1,
						\gate, 1,
						\sync, 1,
						\dens, 1/(~durs[n]*~rates[n%5]),
						\baseDur, ~durs[n],
						\durRand, 1,
						\rate, ~rates[n%5],
						\rateRand, 1,
						\pan, ~panLFO[n],
						\panRand, 0,
						\grainEnv, -1,
						\ptrBus, ~ptrBus,
						\ptrSampleDelay, ~delays[n],
						\ptrRandSamples, s.sampleRate*(~timer.beatDur*((n%8)+1))*2,
						\minPtrDelay, ~delays[n],
						\cutoff, ~cutoffLFO[n],
						\resonance, ~resLFO[n]
					], ~granGrp;
					)
				});

				//up to 8-voice polyphony for synths, round-robin style
				~voices = [\1,\2,\3,\4,\5,\6,\7,\8];
				~voiceManager = Array.fill(32,{PatternProxy(Pseq(~voices, inf)).asStream});

				//fx
				SynthDef(
					"Reverb",
					{
						arg outBus = 0,
						inBus,
						wetness,
						room,
						damp;
						var input,
						verb;
						input = In.ar(
							inBus,
							2
						);
						verb = FreeVerb2.ar(
							input,
							input,
							wetness,
							room,
							damp
						);
						Out.ar(
							outBus,
							verb
						);
					}
				).add;
				s.sync;
				SynthDef(
					"Delay",
					{
						arg outBus = 0,
						inBus,
						revBus,
						delay_time = 1;
						var input;
						input = In.ar(
							inBus,
							2
						);
						input = CombL.ar(
							LeakDC.ar(
								input
							),
							2,
							delay_time,
							20
						);
						Out.ar(
							revBus,
							input
						);
					}
				).add;
				b = Bus.audio(s,2); // this will be our effects bus
				c = Bus.audio(s,2);
				~sendGrp = Group.new(addAction: 'addToTail');
				~fxGrp = Group.after(~sendGrp);
				s.sync;
				a = Synth.new(
					"Delay",
					[
						\inBus, b,
						\revBus, c,
						\outBus, ~fb.index,
						\delay_time, ~timer.beatDur*4
					],
					~fxGrp
				);

				e = Synth.after(
					a,
					"Reverb",
					[
						\inBus, c,
						\wetness, 0.3,
						\room, 0.9,
						\damp, 0.25,
						\outBus, ~fb.index
					],
					~fxGrp
				);

				//scope
				Window.closeAll;
				w = Window("lissajous",Window.screenBounds-[0,-90,0,90],border:false)
				.background_(Color.black)
				.front
				.alwaysOnTop_(true)
				.alpha_(0.5)
				.onClose_({~topScope.stop; ~bf.free; ~fb.free});
				~color_vals = Array.fill(3,{Array.fill(3,{rrand(0,255)})});
				~topScope = ScopeView(w,
					Rect(0,
						0,
						w.view.bounds.width,
						w.view.bounds.height
					)
				)
				.bufnum_(~bf.bufnum)
				.server_(Server.default)
				.style_(2)
				.xZoom_(1)
				.yZoom_(1)
				.waveColors_(
					[
						Color.new255(
							~color_vals[0][0],
							~color_vals[1][0],
							~color_vals[2][0]
						),
						Color.new255(
							~color_vals[0][1],
							~color_vals[1][1],
							~color_vals[2][1]
						)
					]
				)
				.background_(Color.black)
				.start;

				Task({
					var delta = ~timer.beatDur/2;
					loop {
						3.do({
							arg i;
							3.do({
								arg j;
								if(
									~color_vals[i][j] == 255,
									{
										~color_vals[i][j] = ~color_vals[i][j]-[0,1].choose
									}
								);
								if(
									~color_vals[i][j] == 0,
									{
										~color_vals[i][j] = ~color_vals[i][j]+[0,1].choose
									}
								);
								if(
									(~color_vals[i][j] < 255) && (~color_vals[i][j] > 0),
									{
										~color_vals[i][j] = ~color_vals[i][j]+[0,1,-1].wchoose([0.5,0.25,0.25])
									}
								);
							});
						});
						~topScope.waveColors_(
							[
								Color.new255(
									~color_vals[0][0],
									~color_vals[1][0],
									~color_vals[2][0]
								),
								Color.new255(
									~color_vals[0][1],
									~color_vals[1][1],
									~color_vals[2][1]
								)
							]
						);
						delta.yield;
					}
				},AppClock
				).play;

				~af = SynthDef("duoscope", { arg bus, bufnum;
					var z;
					z = In.ar(bus, 2);
					ScopeOut2.ar(z, bufnum);
					Out.ar(0, z);
				}).play(
					target: RootNode(Server.default),
					args: [\bus, ~fb.index, \bufnum, ~bf.bufnum],
					addAction: \addToTail
				);

				//Play the sounds we defined above with OSC commands
				OSCdef(
					\synth_receiver,
					{
						arg msg;
						var voice;
						voice = ~voiceManager[msg[1]-1].next;
						[msg].postln;
						x[msg[1]-1].trigger(voice,msg[2].midicps);
					},
					\synth_osc
				);
				OSCdef(
					\samp_receiver,
					{
						arg msg;
						[msg].postln;
						if(
							msg[1] % 2 == 0,
							{
								x[msg[1]].set(\t_trig,1);
								x[msg[1]].set(\start,msg[3]);
								x[msg[1]].set(\end,msg[4])
							},
							{
								x[msg[1]-1].set(\rate,msg[2])
							}
						)
					},
					\samp_osc
				);
				OSCdef(
					\drum_receiver,
					{
						arg msg;
						var voice;
						voice = ~voiceManager[msg[1]-32].next;
						[msg].postln;
						x[msg[1]].trigger(voice,d[\l][msg[2]-1]);
					},
					\drum_osc
				);
				OSCdef(
					\secret_receiver,
					{
						arg msg;
						[msg].postln;
						if(
							msg[1] == 14,
							{
								~delMic.set(\amp,msg[2])
							}
						);
						if(
							msg[1] == 15,
							{
								15.do({arg i; ~g[i].set(\amp,msg[2])})
							}
						);
						if(
							msg[1] == 16,
							{
								2.do({arg i; ~inMic[i].set(\amp,msg[2])})
							}
						);
					},
					\secret_osc
				);
				OSCdef(
					\synth_params_receiver,
					{
						arg msg;
						[msg].postln;
						x[msg[1]-1].setParam('all',\amp,msg[3]);
						/*if(
							msg[2] == "attack",
							{
								x[msg[1]-1].setParam('all',\attack,msg[3])
							}
						);
						if(
							msg[2] == "release",
							{
								x[msg[1]-1].setParam('all',\release,msg[3])
							}
						);
						if(
							msg[2] == "modnum",
							{
								x[msg[1]-1].setParam('all',\modnum,msg[3])
							}
						);
						if(
							msg[2] == "modeno",
							{
								x[msg[1]-1].setParam('all',\modeno,msg[3])
							}
						);
						if(
							msg[2] == "cutoff_env",
							{
								x[msg[1]-1].setParam('all',\cutoff_env,msg[3])
							}
						);
						if(
							msg[2] == "freq_slew",
							{
								x[msg[1]-1].setParam('all',\freq_slew,msg[3])
							}
						);
						if(
							msg[2] == "pan_slew",
							{
								x[msg[1]-1].setParam('all',\pan_slew,msg[3])
							}
						);
						if(
							msg[2] == "bus",
							{
								if(
									msg[3] == 1,
									{
										x[msg[1]].setParam('all',\bus,b)
									}
								);
								if(
									msg[3] == 2,
									{
										x[msg[1]].setParam('all',\bus,c)
									}
								);
								if(
									msg[3] == 3,
									{
										x[msg[1]].setParam('all',\bus,~micBus)
									}
								);
								if(
									msg[3] == 4,
									{
										x[msg[1]].setParam('all',\bus,~fb.index)
									}
								)
							}
						);*/
					},
					\synth_params
				);
				OSCdef(
					\samp_params_receiver,
					{
						arg msg;
						[msg].postln;
						if(
							msg[1] % 2 == 0,
							{
								x[msg[1]].set(\amp,msg[3])
							}
						)
					},
					\samp_params
				);
				OSCdef(
					\drum_params_receiver,
					{
						arg msg;
						[msg].postln;
						x[msg[1]].setParam('all',\amp,msg[3])
					},
					\drum_params
				);
				16.do({
					arg j;
					8.do({
						arg i;
						x[j].setParam((i+1).asSymbol,\bus,b);
					})
				});
			}
		)
	}
).play(AppClock)
);
x[48]