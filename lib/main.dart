import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WritingKidsApp());
  unawaited(FirebaseServices.initialize());
}

class FirebaseServices {
  static Future<bool>? _future;
  static Future<bool> initialize() => _future ??= _init();
  static Future<bool> _init() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyCcVElxmcZxgeQvj6uM0ho8CAp8JlD_xuM',
          authDomain: 'wykiddo.firebaseapp.com',
          projectId: 'wykiddo',
          storageBucket: 'wykiddo.firebasestorage.app',
          messagingSenderId: '107015497697',
          appId: '1:107015497697:web:8f63aba216b26b700594a0',
          measurementId: 'G-DV312593NY',
        ),
      );
      await AnonymousAuthService.ensureSignedIn(skipInitializationWait: true);
      if (kIsWeb) {
        FirebaseMessaging.onMessage.listen((_) {});
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
          final p = await SharedPreferences.getInstance();
          await p.setString('fcmToken', token);
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

class AnonymousAuthService {
  static Future<User?> ensureSignedIn({bool skipInitializationWait = false}) async {
    try {
      if (!skipInitializationWait && !await FirebaseServices.initialize().timeout(const Duration(seconds: 8))) return null;
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) return auth.currentUser;
      return (await auth.signInAnonymously().timeout(const Duration(seconds: 8))).user;
    } catch (_) {
      return null;
    }
  }
}

class NotificationService {
  static const vapidKey = 'BFXB_NPWFsp-brrQOVZ8GBcZBpgCehPrvc5hl21GrsbIjIOl9REXIrGTbe9GIpILLZV9rDuDJini_-eVadvZu2w';
  static Future<String?> enable() async {
    if (!kIsWeb) return null;
    try {
      if (!await FirebaseServices.initialize().timeout(const Duration(seconds: 8))) return null;
      final m = FirebaseMessaging.instance;
      final s = await m.requestPermission(alert: true, badge: true, sound: true).timeout(const Duration(seconds: 8));
      if (s.authorizationStatus != AuthorizationStatus.authorized) return null;
      final token = await m.getToken(vapidKey: vapidKey).timeout(const Duration(seconds: 8));
      if (token == null || token.isEmpty) return null;
      final p = await SharedPreferences.getInstance();
      await p.setString('fcmToken', token);
      return token;
    } catch (_) {
      return null;
    }
  }
}

class VoiceService {
  static bool _speaking = false;
  static void stop() {
    try { html.window.speechSynthesis.cancel(); } catch (_) {}
    _speaking = false;
  }
  static void speak(String text) {
    stop();
    try {
      final u = html.SpeechSynthesisUtterance(text);
      u.lang = 'en-US';
      u.rate = .78;
      u.pitch = 1.08;
      u.volume = 1;
      u.onEnd.listen((_) => _speaking = false);
      _speaking = true;
      html.window.speechSynthesis.resume();
      html.window.speechSynthesis.speak(u);
    } catch (_) {}
  }
}

class Sfx {
  static final List<AudioPlayer> _players = List.generate(4, (_) => AudioPlayer());
  static int _cursor = 0;
  static bool enabled = true;
  static Future<void> play(String file, {double volume = .65}) async {
    if (!enabled) return;
    final p = _players[_cursor++ % _players.length];
    try {
      await p.stop();
      await p.play(AssetSource('audio/$file'), volume: volume, mode: PlayerMode.lowLatency);
    } catch (_) {}
  }
  static Future<void> dispose() async { for (final p in _players) { await p.dispose(); } }
}

class WritingKidsApp extends StatelessWidget {
  const WritingKidsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Writing Kids',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6C63FF), fontFamily: 'Arial'),
    home: const WelcomePage(),
  );
}

// Small built-in fallback pools, used only if the bundled AI-prepared corpus
// (assets/data/ai_words.json) cannot be loaded (e.g. a corrupted install).
const freeWords = <String>['cat','dog','ball','sun','mom','dad','apple','book','car','cup','hat','fish','boy','girl','red','big','run','sit','jump','bed','pen','pig','bus','box','egg','fox','leg','map','bag','toy'];
const paidWords = <String>['baby','water','happy','house','school','friend','family','flower','rabbit','yellow','green','blue','orange','little','mother','father','sister','brother','pencil','paper','window','garden','cookie','banana','purple','circle','square','number','letter','animal','bird','duck','sheep','horse','tiger','lion','monkey','zebra','rocket','planet','star','cloud','rainbow','summer','winter','morning','night','smile','laugh','play','read','write','draw','count','learn','help','share','clean','wash','sleep','wake','drink','eat','walk','dance','sing','clap','throw','catch','open','close','start','finish','small','large','fast','slow','hot','cold','soft','brown','black','white','notebook','crayon','marker','eraser','ruler','desk','chair','teacher','student','music','story','picture','kitchen','bedroom','sunshine','moon','rain','snow','wind','tree','grass','leaf','stone','road','train','plane','boat','truck','bicycle','shop','market','home','park','zoo','farm','cake','bread','milk','juice','rice','orange','grape','mango','lemon','peach','pear','carrot','potato','tomato','kind','brave','calm','ready','great','amazing','practice','progress','winner','champion','welcome','hello','goodbye'];

/// Loads the bundled one-time AI-prepared word corpus (assets/data/ai_words.json,
/// 500 reviewed paid words + a free sample) so the "New Words" screen actually
/// serves the full library the app advertises, instead of the small built-in
/// fallback list. Falls back silently if the asset is ever missing or malformed,
/// so a bad install can never crash or block the free lessons.
class WordLibrary {
  static List<String> free = List<String>.from(freeWords);
  static List<String> paid = List<String>.from(paidWords);
  static Future<void>? _loading;
  static Future<void> ensureLoaded() => _loading ??= _load();
  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/ai_words.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final f = (data['free'] as List?)?.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      final p = (data['paid'] as List?)?.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      if (f != null && f.isNotEmpty) free = f;
      if (p != null && p.isNotEmpty) paid = p;
    } catch (_) {
      // Keep the built-in fallback words; core learning must never break.
    }
  }
}

class LessonItem { final String text; final String kind; const LessonItem(this.text,this.kind); }
final lessons = <LessonItem>[
  for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) LessonItem(c,'Letter'),
  for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) LessonItem(c,'Letter'),
  for (final c in '0123456789'.split('')) LessonItem(c,'Number'),
  ...freeWords.map((w)=>LessonItem(w,'Word')),
];

class WelcomePage extends StatefulWidget { const WelcomePage({super.key}); @override State<WelcomePage> createState()=>_WelcomePageState(); }
class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  final _music = AudioPlayer();
  late final AnimationController _anim;
  int msg=0; bool music=true;
  static const texts=['Ready to make some magic? ✨','Let’s learn and have fun! 🧸','Every little line makes you better! ✏️','You can do it! 🌟','Little hands, big progress! 🌈','Let’s practice together! 💕'];
  @override void initState(){super.initState(); _checkPending(); _anim=AnimationController(vsync:this,duration:const Duration(seconds:10))..repeat(); _rotate();}
  Future<void> _checkPending() async {
    final p=await SharedPreferences.getInstance();
    final query=html.window.location.search;
    final hasPaymentReturn=query.contains('transaction_id=') || query.contains('status=successful') || p.getString('pendingPaymentEmail')!=null;
    if(hasPaymentReturn && mounted){
      Future.delayed(const Duration(milliseconds:300),(){if(mounted)Navigator.push(context,MaterialPageRoute(builder:(_)=>const PremiumPage()));});
    }
  }
  void _rotate(){Future.delayed(const Duration(seconds:3),(){if(!mounted)return;setState(()=>msg=(msg+1)%texts.length);_rotate();});}
  Future<void> _musicStart() async {if(!music)return;try{await _music.setReleaseMode(ReleaseMode.loop);await _music.play(AssetSource('audio/kids_background.wav'),volume:.12,mode:PlayerMode.media);}catch(_) {}}
  Future<void> _toggle(){setState(()=>music=!music);return music?_musicStart():_music.stop();}
  @override void dispose(){_anim.dispose();_music.dispose();super.dispose();}
  @override Widget build(BuildContext c){final s=MediaQuery.sizeOf(c);return Scaffold(body:Stack(children:[const Positioned.fill(child:_Bg()),...List.generate(14,(i)=>_Float(i,_anim)),SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:700),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Text('🧸',style:TextStyle(fontSize:72)),const SizedBox(height:5),const Text('Writing Kids',style:TextStyle(fontSize:46,fontWeight:FontWeight.w900)),const SizedBox(height:15),AnimatedSwitcher(duration:const Duration(milliseconds:250),child:Text(texts[msg],key:ValueKey(msg),textAlign:TextAlign.center,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800))),const SizedBox(height:32),SizedBox(width:min(s.width*.86,390),height:68,child:FilledButton(onPressed:()async{await _musicStart();if(c.mounted)Navigator.push(c,MaterialPageRoute(builder:(_)=>const HomePage()));},child:const Text('▶  START LEARNING',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)))),IconButton(onPressed:_toggle,icon:Icon(music?Icons.music_note:Icons.music_off)),const Text('Fast • offline-first • no child login required',textAlign:TextAlign.center)])))))]));}
}
class _Bg extends StatelessWidget{const _Bg();@override Widget build(BuildContext c)=>const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(colors:[Color(0xFFFFF8E8),Color(0xFFEAF8FF)])));}
class _Float extends StatelessWidget{final int i;final Animation<double> a;const _Float(this.i,this.a);@override Widget build(BuildContext c){const x=['⭐','☁️','🎈','❤️','✏️','✨','🔤','🌈','🧸','🫧'];return AnimatedBuilder(animation:a,builder:(_,__) {final d=sin(a.value*2*pi+i)*14;return Positioned(left:((i*71)%100)/100*MediaQuery.sizeOf(c).width+d,top:((i*43)%85)/100*MediaQuery.sizeOf(c).height,child:IgnorePointer(child:Opacity(opacity:.33,child:Text(x[i%x.length],style:TextStyle(fontSize:20+i%5*5)))));});}}

class PlayfulBackground extends StatefulWidget { final Widget child; const PlayfulBackground({super.key,required this.child}); @override State<PlayfulBackground> createState()=>_PlayfulBackgroundState(); }
class _PlayfulBackgroundState extends State<PlayfulBackground> with SingleTickerProviderStateMixin { late final AnimationController a; @override void initState(){super.initState();a=AnimationController(vsync:this,duration:const Duration(seconds:12))..repeat();} @override void dispose(){a.dispose();super.dispose();} @override Widget build(BuildContext c)=>Stack(children:[const Positioned.fill(child:_Bg()),...List.generate(8,(i)=>_Float(i,a)),SafeArea(child:widget.child)]); }

class HomePage extends StatelessWidget { const HomePage({super.key});
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Let’s Learn ✨',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const SettingsPage())),icon:const Icon(Icons.settings))]),body:PlayfulBackground(child:ListView(padding:const EdgeInsets.all(18),children:[const SizedBox(height:8),const Text('Pick a fun activity',textAlign:TextAlign.center,style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:18),_Card('🔤','Letters','A–Z uppercase + lowercase',const PracticePage(kind:'Letter')), _Card('🔢','Numbers','0–9',const PracticePage(kind:'Number')), _Card('🐱','Easy Words','Short everyday words',const PracticePage(kind:'Word')), _Card('🦟','Mosquito Pop','Unlimited levels • tap the mosquitoes!',const MosquitoGamePage()), _Card('✨','New Words','AI-prepared word library • engine picks locally',const NewWordsPage()), _Card('⭐','Premium','Unlock the full learning library',const PremiumPage())]))); }
class _Card extends StatelessWidget{final String icon,title,sub;final Widget page;const _Card(this.icon,this.title,this.sub,this.page);@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Card(child:ListTile(contentPadding:const EdgeInsets.all(17),leading:Text(icon,style:const TextStyle(fontSize:38)),title:Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),subtitle:Text(sub),trailing:const Icon(Icons.arrow_forward_ios),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>page)))));}

class PracticePage extends StatefulWidget{final String kind;const PracticePage({super.key,required this.kind});@override State<PracticePage> createState()=>_PracticePageState();}
class _PracticePageState extends State<PracticePage>{late List<LessonItem> items;int i=0,accuracy=0;bool hint=true;bool completed=false;@override void initState(){super.initState();items=lessons.where((x)=>x.kind==widget.kind).toList();}
 LessonItem get cur=>items[i];
 void reset(){setState(() { accuracy=0; completed=false; hint=true; });}
 void next(){setState((){i=(i+1)%items.length;accuracy=0;completed=false;hint=true;});VoiceService.stop();}
 void shuffle(){setState((){items.shuffle();i=0;accuracy=0;completed=false;hint=true;});VoiceService.stop();}
 Future<void> score(double v)async{final p=(v*100).round().clamp(0,100).toInt();final prefs=await SharedPreferences.getInstance();final k='mastery_${widget.kind}_${cur.text}';await prefs.setInt(k,max(prefs.getInt(k)??0,p));if(!mounted)return;setState((){accuracy=p;completed=p>=80&&!hint;});if(p>=80&&!hint)Sfx.play('excellent.wav');else if(p<40)Sfx.play('try_again.wav');else Sfx.play('good.wav',volume:.5);}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(widget.kind,style:const TextStyle(fontWeight:FontWeight.w900))),body:PlayfulBackground(child:ListView(padding:const EdgeInsets.all(18),children:[const Text('TRACE → COPY → WRITE',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),const SizedBox(height:7),Text(hint?'Trace the guide':'Now write it yourself!',textAlign:TextAlign.center),const SizedBox(height:8),Text(cur.text,textAlign:TextAlign.center,style:TextStyle(fontSize:MediaQuery.sizeOf(c).width<500?82:120,fontWeight:FontWeight.w900,color:hint?Colors.black26:null)),Wrap(alignment:WrapAlignment.center,spacing:8,children:[if(hint)TextButton.icon(onPressed:(){setState(()=>hint=false);VoiceService.speak(cur.text);},icon:const Icon(Icons.visibility_off),label:const Text('Hide Guide')),IconButton(tooltip:'Hear pronunciation',onPressed:()=>VoiceService.speak(cur.text),icon:const Icon(Icons.volume_up))]),_TracePad(guide:hint?cur.text:null,onScore:score,onClear:reset),if(accuracy>0)Center(child:Column(children:[Text('$accuracy% accuracy',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:accuracy<40?Colors.red:accuracy<80?Colors.orange:Colors.green)),if(accuracy<40)const Text('Try again — you can do it! 💕'),if(completed)const Text('Amazing! 🎉👏',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18))])),Wrap(alignment:WrapAlignment.center,spacing:7,children:[OutlinedButton.icon(onPressed:reset,icon:const Icon(Icons.refresh),label:const Text('Restart')),OutlinedButton.icon(onPressed:()=>setState(()=>hint=!hint),icon:Icon(hint?Icons.visibility_off:Icons.lightbulb),label:Text(hint?'Hide Hint':'Show Hint')),OutlinedButton.icon(onPressed:shuffle,icon:const Icon(Icons.shuffle),label:const Text('Shuffle')),OutlinedButton.icon(onPressed:next,icon:const Icon(Icons.skip_next),label:const Text('Next'))])));}
}
class _TracePad extends StatefulWidget{final String? guide;final Future<void> Function(double) onScore;final VoidCallback onClear;const _TracePad({required this.guide,required this.onScore,required this.onClear});@override State<_TracePad> createState()=>_TracePadState();}
class _TracePadState extends State<_TracePad>{final strokes=<List<Offset>>[];List<Offset>? active;void clear(){setState((){strokes.clear();active=null;});widget.onClear();}void end(){final s=active;if(s==null||s.length<2)return;setState((){strokes.add(List.of(s));active=null;});final n=strokes.fold<int>(0,(a,b)=>a+b.length);unawaited(widget.onScore(min(1.0,n/180.0)));}
 @override Widget build(BuildContext c){final all=[...strokes,if(active!=null)active!];return Container(height:280,margin:const EdgeInsets.symmetric(vertical:8),decoration:BoxDecoration(color:Colors.white.withOpacity(.9),borderRadius:BorderRadius.circular(24),border:Border.all(width:2)),child:Stack(children:[if(widget.guide!=null)Center(child:IgnorePointer(child:Opacity(opacity:.1,child:Text(widget.guide!,style:const TextStyle(fontSize:170,fontWeight:FontWeight.w900))))),GestureDetector(behavior:HitTestBehavior.opaque,onPanStart:(d){setState(()=>active=[d.localPosition]);Sfx.play('game_tick.wav',volume:.3);},onPanUpdate:(d)=>setState(()=>active?.add(d.localPosition)),onPanEnd:(_)=>end(),child:CustomPaint(painter:_StrokePainter(all),child:const Center(child:Text('Write here ✏️',style:TextStyle(color:Colors.black26,fontSize:20)))),Positioned(right:8,bottom:5,child:IconButton(tooltip:'Clear',onPressed:clear,icon:const Icon(Icons.backspace_outlined))) ]));}}
class _StrokePainter extends CustomPainter{final List<List<Offset>> s;_StrokePainter(this.s);@override void paint(Canvas c,Size z){final p=Paint()..strokeWidth=7..strokeCap=StrokeCap.round;for(final q in s){for(var i=1;i<q.length;i++)c.drawLine(q[i-1],q[i],p);}}@override bool shouldRepaint(covariant _StrokePainter o)=>true;}

class MosquitoGamePage extends StatefulWidget{const MosquitoGamePage({super.key});@override State<MosquitoGamePage> createState()=>_MosquitoGamePageState();}
class Mosquito{Offset p;final double size;double phase;bool dead=false;Mosquito(this.p,this.size,this.phase);}
class _MosquitoGamePageState extends State<MosquitoGamePage> with SingleTickerProviderStateMixin{
 late final AnimationController tick;final rng=Random();final mosquitoes=<Mosquito>[];final bursts=<_Burst>[];int level=1,score=0,missed=0;double kidX=.5;DateTime last=DateTime.now();
 @override void initState(){super.initState();tick=AnimationController(vsync:this,duration:const Duration(days:1))..addListener(_loop)..repeat();_spawnLevel();}
 void _spawnLevel(){mosquitoes.clear();for(var i=0;i<level+2;i++){final edge=rng.nextBool();mosquitoes.add(Mosquito(Offset(edge?(rng.nextBool()?-0.05:1.05):rng.nextDouble(),rng.nextDouble()*.75+.08),28+rng.nextDouble()*8,rng.nextDouble()*6.28));}}
 void _loop(){final now=DateTime.now();final dt=min(.035,now.difference(last).inMilliseconds/1000);last=now;bool changed=false;for(final m in mosquitoes.where((m)=>!m.dead)){final target=Offset(kidX,.83);final d=target-m.p;final len=max(.001,d.distance);m.p+=d/len*(.05+min(level*.006,.55))*dt;m.phase+=dt*5;if((m.p-target).distance<.07){m.dead=true;missed++;changed=true;}}
  for(final b in bursts){b.life-=dt;}bursts.removeWhere((b)=>b.life<=0);if(mosquitoes.every((m)=>m.dead)){level++;_spawnLevel();changed=true;}if(changed&&mounted)setState((){});}
 void hit(Offset local,Size size){final q=Offset(local.dx/size.width,local.dy/size.height);for(final m in mosquitoes.reversed.where((m)=>!m.dead)){final mp=Offset(m.p.dx*size.width,m.p.dy*size.height);if((mp-local).distance<m.size*1.15){m.dead=true;score+=10*level;bursts.add(_Burst(m.p));Sfx.play('mosquito_pop.wav',volume:.75);setState((){});break;}}}
 @override void dispose(){tick.dispose();super.dispose();}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Mosquito Pop 🦟',style:TextStyle(fontWeight:FontWeight.w900))),body:Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,10,16,4),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('Level $level',style:const TextStyle(fontWeight:FontWeight.w900)),Text('Score $score',style:const TextStyle(fontWeight:FontWeight.w900)),Text('Missed $missed',style:const TextStyle(fontWeight:FontWeight.w900))])),Expanded(child:LayoutBuilder(builder:(c,con)=>GestureDetector(onTapDown:(d)=>hit(d.localPosition,Size(con.maxWidth,con.maxHeight)),child:CustomPaint(size:Size.infinite,painter:_GamePainter(mosquitoes,bursts,kidX,level)))),const Padding(padding:EdgeInsets.all(12),child:Text('Stay in your spot and tap the mosquitoes before they reach you! 🧸',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.w700))) ]));}
}
class _Burst{Offset p;double life=0.28;_Burst(this.p);}
class _GamePainter extends CustomPainter{final List<Mosquito> ms;final List<_Burst> bs;final double kid;final int level;_GamePainter(this.ms,this.bs,this.kid,this.level);@override void paint(Canvas c,Size s){c.drawRect(Offset.zero&s,Paint()..color=const Color(0xFFEAF8FF));final kp=Offset(kid*s.width,.84*s.height);final kidPaint=Paint()..color=const Color(0xFFFFC98B);c.drawCircle(kp,30,kidPaint);c.drawCircle(kp.translate(0,-35),22,Paint()..color=const Color(0xFFFFD9B0));for(final m in ms.where((x)=>!x.dead)){final p=Offset(m.p.dx*s.width,m.p.dy*s.height);final wiggle=sin(m.phase)*5;final q=p.translate(wiggle,0);final paint=Paint()..color=const Color(0xFF303030);c.drawCircle(q,8,paint);c.drawLine(q.translate(-10,-3),q.translate(10,3),paint..strokeWidth=3);c.drawCircle(q.translate(-8,-6),5,Paint()..color=Colors.white);c.drawCircle(q.translate(8,-6),5,Paint()..color=Colors.white);}for(final b in bs){final p=Offset(b.p.dx*s.width,b.p.dy*s.height);final r=(1-b.life/.28)*45;final paint=Paint()..color=Colors.red.withOpacity(b.life/.28)..style=PaintingStyle.stroke..strokeWidth=4;c.drawCircle(p,r,paint);}}@override bool shouldRepaint(covariant _GamePainter o)=>true;}

class NewWordsPage extends StatefulWidget{const NewWordsPage({super.key});@override State<NewWordsPage> createState()=>_NewWordsPageState();}
class _NewWordsPageState extends State<NewWordsPage>{final rng=Random();String word='';bool premium=false,loading=true;@override void initState(){super.initState();_load();}Future<void> _load()async{await WordLibrary.ensureLoaded();final p=await SharedPreferences.getInstance();premium=p.getBool('premium')??false;if(!mounted)return;loading=false;_pick();}void _pick(){final pool=premium?[...WordLibrary.free,...WordLibrary.paid]:WordLibrary.free;if(pool.isEmpty)return;String next=word;if(pool.length==1){next=pool.first;}else{do{next=pool[rng.nextInt(pool.length)];}while(next==word);}setState(()=>word=next);} @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('New Words ✨')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:loading?const CircularProgressIndicator():Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(premium?'Full one-time AI-prepared library':'Free one-time AI-prepared library',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:12),Text(word,style:const TextStyle(fontSize:72,fontWeight:FontWeight.w900)),IconButton(onPressed:()=>VoiceService.speak(word),icon:const Icon(Icons.volume_up,size:34)),const SizedBox(height:15),FilledButton.icon(onPressed:_pick,icon:const Icon(Icons.shuffle),label:const Text('Pick another word'))]))));}

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});
  @override State<PremiumPage> createState()=>_PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool busy=false, guardian=false, premium=false;
  final full=TextEditingController(), email=TextEditingController();
  final card=TextEditingController(), expiry=TextEditingController(), cvv=TextEditingController(), pin=TextEditingController(), otp=TextEditingController();
  String currency='NGN', status=''; String? chargeId, nextAuth;

  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();
    final savedEmail=p.getString('premiumEmail'); if(savedEmail!=null)email.text=savedEmail;
    chargeId=p.getString('pendingChargeId'); premium=p.getBool('premium')??false;
    if(mounted)setState((){});
    await _handleReturn(); await _syncSubscription();
  }
  Future<void> _handleReturn() async {
    final q=html.window.location.search; final uri=Uri.tryParse('https://writingkids.local/$q');
    final returned=uri?.queryParameters['charge_id']??uri?.queryParameters['transaction_id']??uri?.queryParameters['id'];
    final id=returned??chargeId; if(id==null||id.isEmpty)return;
    // Only surface a failure message when the parent actually just returned from a
    // payment redirect. A leftover pendingChargeId from days ago should be quietly
    // cleared in the background, not re-shown as a scary error every time this
    // screen opens.
    final hadReturn=returned!=null;
    setState(()=>busy=true);
    try{await _verify(id,silent: !hadReturn);}catch(e){if(hadReturn)status='Payment verification error: $e';}
    if(mounted)setState(()=>busy=false);
    try{html.window.history.replaceState(null,'',html.window.location.pathname);}catch(_){ }
  }
  Future<void> _verify(String id,{bool silent=false}) async {
    final r=await http.get(Uri.parse('/api/payments/verify?charge_id=${Uri.encodeQueryComponent(id)}'));
    final d=jsonDecode(r.body) as Map<String,dynamic>;
    if(r.statusCode>=400)throw Exception(d['message']??'Verification failed');
    final p=await SharedPreferences.getInstance();
    if(d['verified']==true){final mail=d['email']?.toString().toLowerCase();if(mail!=null&&mail.isNotEmpty){await p.setString('premiumEmail',mail);email.text=mail;}await p.setBool('premium',true);await p.remove('pendingChargeId');premium=true;chargeId=null;nextAuth=null;status='Premium subscription activated 🎉';}
    else{await p.remove('pendingChargeId');chargeId=null;if(!silent)status='Payment was not completed successfully. Premium was not unlocked.';}
  }
  Future<void> _syncSubscription() async {
    final p=await SharedPreferences.getInstance();final saved=p.getString('premiumEmail');if(saved==null||saved.isEmpty)return;
    try{final r=await http.get(Uri.parse('/api/payments/subscription?email=${Uri.encodeQueryComponent(saved)}'));if(r.statusCode>=400)return;final d=jsonDecode(r.body) as Map<String,dynamic>;final active=d['active']==true;await p.setBool('premium',active);if(mounted)setState(()=>premium=active);}catch(_){ }
  }
  Future<void> start() async {
    if(!guardian){setState(()=>status='A parent or guardian must confirm the subscription.');return;}
    final name=full.text.trim(),mail=email.text.trim().toLowerCase(),cn=card.text.replaceAll(RegExp(r'\s+'),'');
    if(name.length<2||!RegExp(r'^\S+@\S+\.\S+$').hasMatch(mail)){setState(()=>status='Please enter the parent/guardian name and a valid email.');return;}
    if(cn.length<12||cn.length>19||!RegExp(r'^\d+$').hasMatch(cn)){setState(()=>status='Please enter a valid card number.');return;}
    final exp=expiry.text.replaceAll(RegExp(r'\s|/'),'');
    if(!RegExp(r'^\d{4}$').hasMatch(exp)){setState(()=>status='Expiry must be MMYY.');return;}
    final expMonth=int.tryParse(exp.substring(0,2))??0;
    if(expMonth<1||expMonth>12){setState(()=>status='Expiry month is invalid.');return;}
    if(!RegExp(r'^\d{3,4}$').hasMatch(cvv.text.trim())){setState(()=>status='Please enter a valid CVV.');return;}
    setState(()=>busy=true);
    try{final r=await http.post(Uri.parse('/api/payments/initiate'),headers:{'content-type':'application/json'},body:jsonEncode({'name':name,'email':mail,'cardNumber':cn,'expiry':expiry.text.replaceAll(RegExp(r'\s|/'),''),'cvv':cvv.text.trim(),'currency':currency}));final d=jsonDecode(r.body) as Map<String,dynamic>;if(r.statusCode>=400)throw Exception(d['message']??'Payment could not start');await _handleChargeResponse(d,mail);}catch(e){status='Payment error: $e';}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _handleChargeResponse(Map<String,dynamic>d,String mail)async{
    chargeId=d['chargeId']?.toString();final na=d['nextAction'];nextAuth=na is Map && na['type']=='authorize' ? na['authorization']?['type']?.toString() : na?['type']?.toString();final p=await SharedPreferences.getInstance();if(chargeId!=null)await p.setString('pendingChargeId',chargeId!);await p.setString('pendingPaymentEmail',mail);await p.setString('premiumEmail',mail);
    final redirect=d['redirectUrl']?.toString();if(redirect!=null&&redirect.isNotEmpty){html.window.location.href=redirect;return;}
    final st=d['status']?.toString();if(st=='succeeded'&&chargeId!=null){await _verify(chargeId!);return;}
    if(nextAuth=='requires_pin'||nextAuth=='pin')status='Enter your card PIN to continue.';else if(nextAuth=='requires_otp'||nextAuth=='otp')status='Enter the OTP sent by your bank.';else status='Payment authorization is required to continue.';
  }
  Future<void> authorize(String type)async{
    if(chargeId==null)return;final value=(type=='pin'?pin.text:otp.text).trim();if(value.isEmpty){setState(()=>status='Enter the authorization code first.');return;}setState(()=>busy=true);
    try{final r=await http.post(Uri.parse('/api/payments/authorize'),headers:{'content-type':'application/json'},body:jsonEncode({'chargeId':chargeId,'type':type,'value':value}));final d=jsonDecode(r.body) as Map<String,dynamic>;if(r.statusCode>=400)throw Exception(d['message']??'Authorization failed');final na=d['nextAction'];nextAuth=na is Map && na['type']=='authorize' ? na['authorization']?['type']?.toString() : na?['type']?.toString();final redirect=d['redirectUrl']?.toString();if(redirect!=null&&redirect.isNotEmpty){html.window.location.href=redirect;return;}if(d['status']=='succeeded'){await _verify(chargeId!);}else if(nextAuth=='requires_otp'||nextAuth=='otp'){status='Enter the OTP sent by your bank.';}else if(nextAuth=='requires_pin'||nextAuth=='pin'){status='Enter your card PIN to continue.';}else status='Additional payment authorization is required.';}catch(e){status='Payment authorization error: $e';}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> cancelSubscription()async{final mail=email.text.trim().toLowerCase();if(!RegExp(r'^\S+@\S+\.\S+$').hasMatch(mail))return;setState(()=>busy=true);try{final r=await http.post(Uri.parse('/api/payments/cancel'),headers:{'content-type':'application/json'},body:jsonEncode({'email':mail}));final d=jsonDecode(r.body) as Map<String,dynamic>;if(r.statusCode>=400)throw Exception(d['message']??'Could not cancel');final p=await SharedPreferences.getInstance();await p.setBool('premium',false);premium=false;status='Premium has been cancelled. No further automatic charges will be made.';}catch(e){status='Cancellation error: $e';}finally{if(mounted)setState(()=>busy=false);}}
  @override void dispose(){full.dispose();email.dispose();card.dispose();expiry.dispose();cvv.dispose();pin.dispose();otp.dispose();super.dispose();}
  InputDecoration dec(String s)=>InputDecoration(labelText:s,border:const OutlineInputBorder());
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Premium')),body:ListView(padding:const EdgeInsets.all(20),children:[
    Text(premium?'Premium active 🎉':r'$1.99 / ₦2,000 monthly',style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900)),const SizedBox(height:8),
    const Text('Recurring monthly subscription. Choose your billing currency. Your saved card is tokenized by Flutterwave; Writing Kids never stores the card number or CVV.'),const SizedBox(height:12),
    CheckboxListTile(value:guardian,onChanged:busy?null:(v)=>setState(()=>guardian=v??false),title:const Text('I am the parent/guardian making this purchase.'),contentPadding:EdgeInsets.zero),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(value:currency,decoration:dec('Billing currency'),items:const[DropdownMenuItem(value:'NGN',child:Text('₦2,000 NGN / month')),DropdownMenuItem(value:'USD',child:Text(r'$1.99 USD / month'))],onChanged:busy?null:(v)=>setState(()=>currency=v??'NGN')),
    const SizedBox(height:12),TextField(controller:full,enabled:!busy,decoration:dec('Parent/guardian full name')),const SizedBox(height:10),TextField(controller:email,enabled:!busy,keyboardType:TextInputType.emailAddress,decoration:dec('Email for subscription')),const SizedBox(height:10),
    TextField(controller:card,enabled:!busy,keyboardType:TextInputType.number,obscureText:true,decoration:dec('Card number')),const SizedBox(height:10),
    Row(children:[Expanded(child:TextField(controller:expiry,enabled:!busy,keyboardType:TextInputType.number,decoration:dec('Expiry MMYY'))),const SizedBox(width:10),Expanded(child:TextField(controller:cvv,enabled:!busy,keyboardType:TextInputType.number,obscureText:true,decoration:dec('CVV')))]),const SizedBox(height:15),
    FilledButton(onPressed:busy||premium?null:start,child:Text(busy?'PROCESSING…':r'SUBSCRIBE — $1.99 / ₦2,000 MONTHLY')),
    if(nextAuth=='requires_pin'||nextAuth=='pin')...[_authField(pin,'Card PIN'),FilledButton(onPressed:busy?null:()=>authorize('pin'),child:const Text('CONTINUE WITH PIN'))],
    if(nextAuth=='requires_otp'||nextAuth=='otp')...[_authField(otp,'OTP code'),FilledButton(onPressed:busy?null:()=>authorize('otp'),child:const Text('VERIFY OTP'))],
    if(premium)Padding(padding:const EdgeInsets.only(top:10),child:OutlinedButton(onPressed:busy?null:cancelSubscription,child:const Text('CANCEL PREMIUM'))),
    if(status.isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Text(status,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700))),const SizedBox(height:18),
    const Text('Security: card details are sent over HTTPS to the Writing Kids server, encrypted with the Flutterwave v4 encryption key, and used to create a Flutterwave payment method. Only Flutterwave payment-method/customer IDs are retained for recurring billing. PIN and CVV are never stored.',style:TextStyle(fontSize:12)),
  ]));
  Widget _authField(TextEditingController c,String label)=>Padding(padding:const EdgeInsets.only(top:10),child:TextField(controller:c,enabled:!busy,keyboardType:TextInputType.number,obscureText:true,decoration:dec(label)));
}

class SettingsPage extends StatefulWidget{const SettingsPage({super.key});@override State<SettingsPage> createState()=>_SettingsPageState();}
class _SettingsPageState extends State<SettingsPage>{bool reminders=false,enabling=false,premium=false;String status='Study reminders are free.';@override void initState(){super.initState();_load();}Future<void> _load()async{final p=await SharedPreferences.getInstance();final savedEmail=p.getString('premiumEmail');var active=p.getBool('premium')??false;if(savedEmail!=null&&savedEmail.isNotEmpty){try{final r=await http.get(Uri.parse('/api/payments/subscription?email=${Uri.encodeQueryComponent(savedEmail)}'));if(r.statusCode<400){final d=jsonDecode(r.body) as Map<String,dynamic>;active=d['active']==true;await p.setBool('premium',active);}}catch(_){}}if(mounted)setState((){reminders=p.getBool('reminders')??false;premium=active;});}Future<void> _toggle(bool v)async{if(!v){final p=await SharedPreferences.getInstance();await p.setBool('reminders',false);setState(()=>reminders=false);return;}setState(()=>enabling=true);final t=await NotificationService.enable();if(!mounted)return;if(t==null){setState(() { enabling=false; status='Push permission/setup was not completed. Core learning still works.'; });return;}final p=await SharedPreferences.getInstance();await p.setBool('reminders',true);setState(() { enabling=false; reminders=true; status='Push notifications are enabled on this browser.'; });}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Parent Settings')),body:ListView(padding:const EdgeInsets.all(20),children:[Card(child:SwitchListTile(title:const Text('Free Study Notifications'),subtitle:Text(status),value:reminders,onChanged:enabling?null:_toggle)),if(enabling)const LinearProgressIndicator(),Card(child:ListTile(title:Text(premium?'Premium active 🎉':'Premium not active'),subtitle:const Text('Manage learning access'),trailing:const Icon(Icons.arrow_forward_ios),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const PremiumPage())))),const SizedBox(height:10),_InfoPageButton('Privacy',_legalPrivacy),_InfoPageButton('Terms',_legalTerms),_InfoPageButton('About',_legalAbout),_InfoPageButton('Disclaimer',_legalDisclaimer),const SizedBox(height:14),const Text('Core lessons do not require an account or network. Web push and payment services are optional and can fail without blocking learning.') ]));}
}
class _InfoPageButton extends StatelessWidget{final String title,body;const _InfoPageButton(this.title,this.body);@override Widget build(BuildContext c)=>Card(child:ListTile(title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>InfoPage(title:title,body:body)))));}
const _legalPrivacy='Writing Kids is designed to minimize personal data. Core lessons and progress stay on the device. Optional Firebase services may use an anonymous identifier and a push token when notifications are enabled. Payment details are sent only for payment processing and must not be stored by the app. We do not intentionally collect children’s location, contacts, photos or advertising identifiers for core learning. Parents should review the applicable app-store privacy disclosures and provider notices.';
const _legalTerms='Writing Kids is educational software for family learning. Use it with appropriate adult supervision. Premium is a recurring monthly subscription priced at $1.99 USD or ₦2,000 NGN depending on the selected billing currency. Flutterwave v4 tokenizes the payment method for future recurring charges. Cancel before the next billing date to stop future charges. Premium access is granted only after server-side verification. Educational outcomes are not guaranteed.';
const _legalAbout='Writing Kids is a lightweight handwriting practice app built around TRACE → COPY → WRITE, simple words, pronunciation, progress and playful mini-games. The core learning experience is designed to remain useful offline and on slower devices.';
const _legalDisclaimer='Writing Kids is an educational practice tool, not medical, therapeutic, diagnostic or professional educational advice. Children may need parent, teacher or specialist support. Internet-dependent services such as push notifications and payments may be unavailable. Card entry is transmitted securely to the server and encrypted for Flutterwave v4 processing; PIN, OTP and 3-D Secure steps are handled by Flutterwave and the issuing bank. Premium is recurring and may continue charging until cancelled.';
class InfoPage extends StatelessWidget{final String title,body;const InfoPage({super.key,required this.title,required this.body});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(title)),body:SingleChildScrollView(padding:const EdgeInsets.all(22),child:Text(body,style:const TextStyle(fontSize:16,height:1.55))));}
