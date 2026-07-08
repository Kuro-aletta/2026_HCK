import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
//import ddf.minim.signals.*;
//import ddf.minim.spi.*;
import ddf.minim.ugens.*;

//import ddf.minim.*;
//import ddf.minim.ugens.*;
//import ddf.minim.analysis.*;

//import ddf.minim.effects.*; // 追加

import processing.serial.*;
Serial myPort;

Minim minim;
AudioOutput out;
FFT fft;

int musicBPM = 120;

String timbre = "Flute";

byte soundOctave = 60;
byte soundDoReMi = 9;

byte soundStartVelocity = 96;
byte soundEndVelocity = 96;





float currentMasterVolume = 1.0;

// 0:なし　1:フルート　2:ストリングス　3:ピアノ　4:ドラム
final byte arduinoNumber = 3;

boolean isDebugMode = true;



// 反響音用
Summer longOut;
Summer shortOut;


InstrumentPlayer player;
DataUtils utils;








void setup()
{
  size(1024, 850);
  minim = new Minim(this);
  out = minim.getLineOut(Minim.MONO, 1024);
  
  // --- 1. エフェクト専用のバス（部屋）を3つだけ作る ---
  // 1. ストリングス専用のバス（通り道）を生成 (UGen)
  /*longOut = new Summer();
  // 2. 新しいUGen形式の反響音エフェクトを生成 (UGen)
  SimpleConvolutionUGen longReverb = new SimpleConvolutionUGen(20000, 0.17f);
  // 3. 【超重要】すべてを .patch() で数珠繋ぎ（シグナルチェーン）にする
  longOut.patch(longReverb);  // ミキサーの音を、反響音エフェクトへ流す
  longReverb.patch(out); */        // 反響音エフェクトの音を、全体の出口へ流す
  
  longOut = new Summer();
  AddReverb longReverb = new AddReverb(15000, 0.20f);
  longOut.patch(longReverb);
  longReverb.patch(out);
  
  shortOut = new Summer();
  AddReverb shortReverb = new AddReverb(2000, 0.25f);
  shortOut.patch(shortReverb);
  shortReverb.patch(out);
  
  
  player = new InstrumentPlayer(out); // thisとoutを渡す
  
  // ★ここに追記：過去2000サンプル（約45ミリ秒分）を参照する反響音を適用
  //out.patch(new SimpleConvolutionEffect(15000));
  
  //out.setTempo (musicBPM);
  //currentWaveform = Waves.SINE;
  
  utils = new DataUtils();
  // 1. float型の二次元配列を取得
  float[][] Note_f = utils.GetLUT("Note");
  // 2. Note_fと同じ大きさで、int型の二次元配列「Note」を作成
  Note = new int[Note_f.length][Note_f[0].length];
  // 3. 2重ループで1要素ずつint型に変換して代入
  for (int i = 0; i < Note_f.length; i++) {
    for (int j = 0; j < Note_f[i].length; j++) {
      Note[i][j] = int(Note_f[i][j]); // 小数点以下は切り捨て
    }
  }
  
  out.setGain(-6.0f);
  
  fft = new FFT(out.bufferSize(), out.sampleRate());
  
  
  
  audioThread = new Thread(new Runnable() {
    public void run() {
      while (true) {
        if (isPlaying && isDebugMode) {
          long getTime = System.nanoTime();
          while (getTime - lastTime >= interval) {
            SoundPlay();
            lastTime += interval;
            tick++;
          }
        }
        
        
        // CPUの暴走（負荷100%）を防ぐため、1ミリ秒だけ休憩させる
        // これにより、毎秒1000回の頻度で正確にタイマーがチェックされます
        //try {
        //  Thread.sleep(interval / 1000000000 *2); 
        //  //Thread.sleep(1);
        //} catch (InterruptedException e) {
        //  break; // エラーが起きたらループを抜ける
        //}
        
        
        // ➔ 休憩（sleep）を廃止し、CPUに「超高速空回り中」と伝えるだけにする
        //Thread.onSpinWait(); 
        
        
        
        else {
          // 停止中はCPUを休ませる
          try { Thread.sleep(100); } catch (InterruptedException e) {}
        }

        // ➔ sleep(1) を廃止し、これに置き換える
        if (isPlaying) {
          Thread.onSpinWait(); // CPUに「今は待機中だよ」と伝えて効率化する（Java 9以降）
        }
      }
    }
  });
  audioThread.start(); // スレッドをスタート！
  //fpsCheckStartTime = System.nanoTime();
  
  
  // シリアル通信開始処理
  println("=== 利用可能なシリアルポート ===");
  String portList[] = Serial.list();
  println(portList); // ポート一覧を確認
  myPort = new Serial(this, portList[2], 115200); // ポートは適切に変更
  myPort.bufferUntil('\n'); // 開業まで溜めてから
  println("受信待機中・・・");
  println("==========");
  
}



void draw()
{
  background(0);
  //if (!(isPlaying && isDebugMode)) {
  // --- オシロスコープの描画 ---
  stroke(255);
  for (int i=0; i < out.bufferSize() - 1; i++) {
    float x1 = map(i, 0, out.bufferSize(), 0, width);
    float x2 = map(i+1, 0, out.bufferSize(), 0, width);
    line(x1, 150 - out.left.get(i)*250, x2, 150 - out.left.get(i+1)*250);
  }
  
  // --- スペクトルアナライザの描画 ---
  fft.forward(out.mix);
  stroke(255, 0, 255);
  
  for(int i = 0; i < fft.specSize() - 1; i++) {
    // FFTのインデックスが何Hzに相当するか取得
    float f1 = fft.indexToFreq(i);
    float f2 = fft.indexToFreq(i+1);
    
    // 表示範囲(20〜20000Hz)から外れる場合は線を描画しない
    if (f2 < 20 || f1 > 20000) continue;
    
    float amp1 = fft.getBand(i);
    float amp2 = fft.getBand(i+1);
    
    float y1 = 800 - amp1 * 4;
    float y2 = 800 - amp2 * 4;
    
    // 専用関数を使ってX座標を計算
    float x1 = FreqToX(f1);
    float x2 = FreqToX(f2);
    
    line(x1, y1, x2, y2);
  }
  
  // --- 周波数の目盛りとラベルの描画 (X軸) ---
  fill(255);
  textSize(12);
  textAlign(CENTER, TOP);
  
  // 添付画像通りの目盛りとラベルの配列
  float[] labelFreqsX = {20, 30, 40, 50, 60, 80, 100, 200, 300, 400, 500,
                         800, 1000, 2000, 3000, 4000, 6000, 8000, 10000, 20000};
  String[] labelStrsX = {"20", "30", "40", "50", "60", "80", "100", "200", "300", "400", "500",
                         "800", "1k", "2k", "3k", "4k", "6k", "8k", "10k", "20k"};
  
  for (int i = 0; i < labelFreqsX.length; i++) {
    float x = FreqToX(labelFreqsX[i]);
    
    stroke(100); // 縦線（薄いグレー）
    line(x, 300, x, 820);
    
    fill(200);
    text(labelStrsX[i], x, 830); 
  }
  
  // --- 振幅の目盛りとラベルの描画 (Y軸) ---
  textAlign(RIGHT, CENTER); // テキストを右揃えにして数値を綺麗に並べる
  
  // 振幅(amp)を0から120まで、20刻みで横線を描画します (上限を160から120に変更)
  for (int amp = 20; amp <= 120; amp += 20) {
    // スペクトルアナライザの描画と同じ計算式を使用
    float y = 800 - amp * 4;
    
    // オシロスコープの描画領域（Y=300より上）に被らない場合のみ描画
    if (y >= 320) {
      stroke(50); // 横線（暗いグレー）
      line(40, y, width, y); // 数値ラベルと被らないようにX=40から開始
      
      fill(200);
      text(amp, 35, y); // 左端に振幅の数値を描画
    }
  }
  
  // 操作説明
  //fill(200);
  //textAlign(LEFT, TOP);
  //text("Press 'p' to play song. Press '1'-'6' to change waveform.", 20, 20);
  //}
  
  
  /*
  if (isPlaying && isDebugMode) {
    long getTime = System.nanoTime();
    // 現在の時間と、前回記録した時間の差分を計算
    // if ではなく while にすることで、遅れた分（数tick分）をこの1フレーム内で一気に処理します
    while (getTime - lastTime >= interval) {
      tick++;             
      SoundPlay();
      lastTime += interval; // すっきりした累積補正の式
    }
  }
  */
  /*
  long a = System.nanoTime();
  fps ++;
  if (fpsCheckStartTime + 1000000000L <= a) {
    fpsCheckStartTime += 1000000000L;
    println(fps);
    fps = 0;
  }
  */
}
//long fpsCheckStartTime;
//int fps = 0;

// --- 周波数を対数スケールのX座標に変換する関数 ---
float FreqToX(float f) {
  float minFreq = 20.0f;
  float maxFreq = 20000.0f;
  
  // 範囲外の値を制限する
  if (f < minFreq) f = minFreq;
  if (f > maxFreq) f = maxFreq;
  
  // log() を使って対数スケールにマッピングする
  return map(log(f), log(minFreq), log(maxFreq), 0, width);
};



//音符数と遅延の関係を調査したときに使用
//int noteChecker = 0;

void serialEvent(Serial p) {
  //println("受信");
  // 改行まで文字列を読み込む
  String inString = p.readStringUntil('\n');
  
  // 何も読み込めなかった場合は処理停止
  if (inString == null) return;
  
  // 末尾の改行コードや余分な空白を削除
  inString = trim(inString); 
  
  // カンマで分割して配列にする
  String[] list = split(inString, ',');
  
  // データが空の場合は処理停止
  if (list.length <= 1) return;
  
  // ヘッダとデータ数
  String header = list[0];
  int listLength = list.length - 1;
  
  //　ヘッダによる分岐
  switch (header) {
    
    // 発音指示
    case "N" :
      if (listLength % 5 != 0) break;
      for (int i = 5; i <= listLength; i += 5) {
        
        float pitch, duration, startVel, endVel, type;
        try {
          pitch    = float(list[i-4]);
          duration = float(list[i-3]) * (2.5f / musicBPM); // 60000÷(BPM*24)
          startVel = float(list[i-2]);
          endVel   = float(list[i-1]);
          type     = int(list[i]);
          println("N受信(" + list[i-4] + ", " + list[i-3] + ", " + list[i-2] + ", " + list[i-1] + ", " + list[i] + ")"); 
        } catch (NumberFormatException e) {
          continue;
        }
        // 数値の場合のみ処理続行
        
        /*if (pitch  == 72) {
          if (noteChecker == 0) noteChecker -= millis();
          else {noteChecker += millis(); println("所要時間: " + noteChecker); noteChecker = 0;}
        }*/
        
        switch (arduinoNumber) {
          case 1 :
            player.PlayFlute(pitch, duration, startVel, endVel, currentMasterVolume);
            break;
          case 2 :
            player.PlayStrings(pitch, duration, startVel, endVel, currentMasterVolume);
            break;
          case 3 :
            if      (type == 0) player.PlayPiano(pitch, duration, startVel, currentMasterVolume);
            else if (type == 1) player.PlayTrumpet(pitch, duration, startVel, endVel, currentMasterVolume);
            else if (type == 2) player.PlayHorn(pitch, duration, startVel, endVel, currentMasterVolume);
            break;
          case 4 :
            int a = int(list[i-4]) % 12;
            if      (a == 0) player.PlayKick(currentMasterVolume, startVel);
            else if (a == 3) player.PlaySnare(currentMasterVolume, startVel, endVel);
            else if (a == 4) player.PlayHiHat(currentMasterVolume, startVel);
            break;
          default: break;
        }
      }
      break;
      
    // BPM変更指示（60~180）
    case "B" :
      if (listLength != 1) break;
      int getBPM;
      try {
        getBPM = int(list[1]);
        println("B受信 (" + list[1] + ")");
      } catch (NumberFormatException e) {
        break;
      }
      // 数値の場合のみ処理続行
      int minimumBPM = 60;
      int maximumBPM = 180;
      musicBPM = constrain(getBPM, minimumBPM, maximumBPM);
      break;
      
    // マスターボリューム変更指示（0~255）
    case "V" :
      if (listLength != 1) break;
      float getVolume;
      try {
        getVolume = float(list[1]);
        println("V受信 (" + list[1] + ")");
      } catch (NumberFormatException e) {
        break;
      }
      // 数値の場合のみ処理続行
      float minimumVolume = 10.0f;
      float maximumVolume = 50.0f;
      currentMasterVolume = map( constrain( getVolume, minimumVolume, maximumVolume), minimumVolume, maximumVolume, 0.2, 1.0);
      break;
      
    default: break;
  }
}








void Play()
{
  switch(timbre){
    case "Flute":
      player.PlayFlute(soundOctave + soundDoReMi, 2.0f, soundStartVelocity, soundEndVelocity, 1.0f);
      break;
    //case "Flure2":
    //  player.PlayFlute(soundOctave + soundDoReMi + 128, 4.0f, soundStartVelocity, soundEndVelocity, 1.0f);
    //  break;
    case "Strings":
      player.PlayStrings(soundOctave + soundDoReMi, 2.3f, soundStartVelocity, soundEndVelocity, 1.0f);
      break;
    case "Drum":
      if (soundDoReMi == 0) {
        player.PlayKick(1.0f, soundStartVelocity);
      } else if (soundDoReMi == 1) {
        player.PlaySnareOld(1.0f, soundStartVelocity);
      } else if (soundDoReMi == 2) {
        player.PlayHiHatOld(1.0f, soundStartVelocity);
      } else if (soundDoReMi == 3) {
        player.PlaySnare(1.0f, soundStartVelocity, soundEndVelocity);
      } else if (soundDoReMi == 4) {
        player.PlayHiHat(1.0f, soundStartVelocity);
      } //else if (soundDoReMi == 5) {
      //  player.PlayCymbal(1.0f, soundStartVelocity);
      //}
      break;
    case "Piano":
      //int a = millis();
      player.PlayPiano(soundOctave + soundDoReMi, 10.0f, soundStartVelocity, 1.0f);
      //a = millis()-a;
      //println("経過時間: " + a);
      break;
    case "Horn":
      player.PlayHorn(soundOctave + soundDoReMi, 1.0f, soundStartVelocity, soundEndVelocity, 1.0f);
      break;
    case "Trumpet":
      player.PlayTrumpet(soundOctave + soundDoReMi, 1.0f, soundStartVelocity, soundEndVelocity, 1.0f);
      break;
  }
}



void keyPressed() {
  if (isDebugMode == false) return;
  switch (key)
  {
  case '1':
    soundOctave = 24;
    break;
  case '2':
    soundOctave = 36;
    break;
  case '3':
    soundOctave = 48;
    break;
  case '4':
    soundOctave = 60;
    break;
  case '5':
    soundOctave = 72;
    break;
  case '6':
    soundOctave = 84;
    break;
  case '7':
    soundOctave = 96;
    break;
    
  case '0':
    soundStartVelocity = 127;
    break;
  case '-':
    soundStartVelocity = 112;
    break;
  case 'o':
    soundStartVelocity = 96;
    break;
  case 'p':
    soundStartVelocity = 80;
    break;
  case 'l':
    soundStartVelocity = 64;
    break;
  case ';':
    soundStartVelocity = 48;
    break;
  case ',':
    soundStartVelocity = 32;
    break;
  case '.':
    soundStartVelocity = 16;
    break;
  case '^':
    soundEndVelocity = 127;
    break;
  case '¥':
    soundEndVelocity = 112;
    break;
  case '@':
    soundEndVelocity = 96;
    break;
  case '[':
    soundEndVelocity = 80;
    break;
  case ':':
    soundEndVelocity = 64;
    break;
  case ']':
    soundEndVelocity = 48;
    break;
  case '/':
    soundEndVelocity = 32;
    break;
  case '_':
    soundEndVelocity = 16;
    break;
    
  case 'a':
    soundDoReMi = 0;
    Play();
    break;
  case 'w':
    soundDoReMi = 1;
    Play();
    break;
  case 's':
    soundDoReMi = 2;
    Play();
    break;
  case 'e':
    soundDoReMi = 3;
    Play();
    break;
  case 'd':
    soundDoReMi = 4;
    Play();
    break;
  case 'f':
    soundDoReMi = 5;
    Play();
    break;
  case 't':
    soundDoReMi = 6;
    Play();
    break;
  case 'g':
    soundDoReMi = 7;
    Play();
    break;
  case 'y':
    soundDoReMi = 8;
    Play();
    break;
  case 'h':
    soundDoReMi = 9;
    Play();
    break;
  case 'u':
    soundDoReMi = 10;
    Play();
    break;
  case 'j':
    soundDoReMi = 11;
    Play();
    break;
    
  case 'z':
  case 'Z':
    timbre = "Flute";
    break;
  //case 'x':
  //case 'X':
  //  timbre = "Flure2";
  //  break;
  case 'c':
  case 'C':
    timbre = "Strings";
    break;
  case 'v':
  case 'V':
    timbre = "Drum";
    break;
  case 'b':
  case 'B':
    timbre = "Piano";
    break;
  case 'n':
  case 'N':
    timbre = "Horn";
    //Oscil sawOsc = new Oscil(37, 0.1, Waves.SQUARE);
    //sawOsc.patch(new HighPassSP(500f, out.sampleRate())).patch(out);
    //sawOsc = new Oscil(199, 0.01, Waves.SQUARE);
    //sawOsc.patch(new HighPassSP(1000f, out.sampleRate())).patch(out);
    //sawOsc = new Oscil(347, 0.01, Waves.SAW);
    //sawOsc.patch(new HighPassSP(1800f, out.sampleRate())).patch(out);
    //sawOsc = new Oscil(433, 0.01, Waves.SQUARE);
    //sawOsc.patch(new HighPassSP(2200f, out.sampleRate())).patch(out);
    //sawOsc = new Oscil(859, 0.01, Waves.SAW);
    //sawOsc.patch(new HighPassSP(5000f, out.sampleRate())).patch(out);
    //sawOsc = new Oscil(2100, 0.01, Waves.SAW);
    //sawOsc.patch(new HighPassSP(9000f, out.sampleRate())).patch(out);
    //sawOsc = new Oscil(71, 0.01, Waves.SQUARE);
    //sawOsc.patch(new HighPassSP(600f, out.sampleRate())).patch(out);
    //sawOsc = new Oscil(47, 0.01, Waves.SAW);
    //sawOsc.patch(new HighPassSP(550f, out.sampleRate())).patch(out);
    //sawOsc = new Oscil(13, 0.01, Waves.SAW);
    //sawOsc.patch(new HighPassSP(300f, out.sampleRate())).patch(out);
    break;
  case 'm':
  case 'M':
    timbre = "Trumpet";
    break;
    
    
    
    
    
    case 'A' : // 酒場でブギウギ
      tick = 1536;
      returnTick = new int[][] {{2880, 1728, 48}, {2784, 2880, 281}, {4512, 1728, 48}};
      returnIndex = 0;
      noteIndex = 29;
      interval = GetInterval( 139 );
      lastTime = System.nanoTime();
      isPlaying = true;
      break;
      
    case 'S' : // かえるのうた（オクターブ５）
      tick = 0;
      returnTick = new int[][] {{1536, 0, 0}};
      returnIndex = 0;
      noteIndex = 0;
      interval = GetInterval( 120 );
      lastTime = System.nanoTime();
      isPlaying = true;
      break;
      
    case 'D' : // 王宮のメヌエット（強弱なし）
      tick = 4608;
      returnTick = new int[][] {{5760, 4608, 651}, {5736, 5832, 850}, {6432, 5856, 856}, {6216, 6456, 993}, {6816, 4608, 651}, {5760, 6816, 1046}, {8832, 4608, 651}};
      returnIndex = 0;
      noteIndex = 651;
      interval = GetInterval( 122 );
      lastTime = System.nanoTime();
      isPlaying = true;
      break;
      
    case 'F' : // トルコ行進曲
      tick = 8856;
      returnTick = new int[][] {{9240, 8856, 1399}, {10008, 9240, 1499}, {10392, 10008, 1669}, {10776, 10392, 1783}, {11544, 10776, 1895}, {11544, 10008, 1669}, {10392, 10008, 1669}, {10392, 8856, 1399}, {9240, 8856, 1399}, {10008, 11544, 2111}, {11928, 11544, 2111}, {11904, 11952, 2225}, {13632, 8856, 1399}};
      returnIndex = 0;
      noteIndex = 1399;
      interval = GetInterval( 120 );
      lastTime = System.nanoTime();
      isPlaying = true;
      break;
      
    case 'G' : // 序曲_中盤（製作中用）
      tick = 96;
      returnTick = new int[][] {{1608, 72, 0}};
      returnIndex = 0;
      noteIndex = 0;
      interval = GetInterval( 120 );
      lastTime = System.nanoTime();
      isPlaying = true;
      break;
      
    case 'H' : // 序曲_終盤なし
      tick = 13632;
      //returnTick = new int[][] {{16488, 14952, 2899}}; // ピアノ用
      returnTick = new int[][] {{16488, 14952, 3053}}; // ストリングス用
      //returnTick = new int[][] {{16488, 14952, 2985}}; // フルート用
      returnIndex = 0;
      noteIndex = 2638;
      interval = GetInterval( 120 );
      lastTime = System.nanoTime();
      isPlaying = true;
      break;
      
    case 'J' : // 序曲_ドラム用
      tick = 768;
      returnTick = new int[][] {{3624, 2088, 637}};
      returnIndex = 0;
      noteIndex = 92;
      interval = GetInterval( 120 );
      lastTime = System.nanoTime();
      isPlaying = true;
      break;
      
    case 'Q' : // 演奏停止
      isPlaying = false;
      break;
      
    default:
      break;
  }
}
