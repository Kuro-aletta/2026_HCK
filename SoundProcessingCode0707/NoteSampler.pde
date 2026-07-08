// 既存の変数に volatile をつける
volatile int tick;
volatile long interval;
volatile long lastTime = 0;
volatile int[][] returnTick; // {トリガーtick, ジャンプ先tick, ジャンプ先noteIndex}
volatile int returnIndex;
volatile int noteIndex;
volatile boolean isPlaying = false;

// 音楽専用スレッド用の変数を追加
Thread audioThread;




long GetInterval (int playBPM) {
  return 60000000000L / (playBPM * 24);
}



void SoundPlay() {
  if (tick == returnTick[returnIndex][0]) {
    tick = returnTick[returnIndex][1];
    noteIndex = returnTick[returnIndex][2];
    returnIndex ++;
    if (returnIndex == returnTick.length) returnIndex = 0;
  }
  
  if (noteIndex < Note.length) {
    //long a = System.nanoTime();
    float durationTuning = interval / 1000000000.0f;
    while (Note[noteIndex][0] == tick) {
      float duration = float(Note[noteIndex][1]) * durationTuning;
      float pitch = float(Note[noteIndex][2]);
      float startVelocity = float(Note[noteIndex][3]);
      float endVelocity = float(Note[noteIndex][4]);          //startVelocity=127; endVelocity=127;
      float type = (Note[noteIndex].length == 6) ? float(Note[noteIndex][5]) : 0;
      switch (timbre) {
        case "Flute": case "Flute2":
          player.PlayFlute(pitch, duration, startVelocity, endVelocity, 1.0f);
          break;
        case "Strings":
          player.PlayStrings(pitch, duration, startVelocity, endVelocity, 1.0f);
          break;
        case "Piano":
          if      (type == 0) player.PlayPiano(pitch, duration, startVelocity, 1.0f);
          else if (type == 1) player.PlayTrumpet(pitch, duration, startVelocity, endVelocity, 1.0f);
          else if (type == 2) player.PlayHorn(pitch, duration, startVelocity, endVelocity, 1.0f);
          break;
        case "Drum":
          int a = int(pitch) % 12;
          if      (a == 0) player.PlayKick(1.0f, startVelocity);
          //else if (a == 1) player.PlaySnareOld(1.0f, startVelocity);
          //else if (a == 2) player.PlayHiHatOld(1.0f, startVelocity);
          else if (a == 3) player.PlaySnare(1.0f, startVelocity, endVelocity);
          else if (a == 4) player.PlayHiHat(1.0f, startVelocity);
          break;
        case "Horn":
          player.PlayHorn(pitch, duration, startVelocity, endVelocity, 1.0f);
          break;
        case "Trumpet":
          player.PlayTrumpet(pitch, duration, startVelocity, endVelocity, 1.0f);
          break;
        default:
          break;
      }
      noteIndex ++;
      if (noteIndex == Note.length) break;
    }
    //println(System.nanoTime() - a);
  }
}





int[][] Note = {
// ドラム用楽譜（setupでの上書きをコメント文にすれば演奏可能）


  // 【1小節目】
  {0, 96, 72, 96, 96, 0}, // [0] C5

  // 【3小節目】
  {192, 96, 74, 96, 96, 0}, // [1] D5

  // 【5小節目】
  {384, 96, 76, 96, 96, 0}, // [2] E5

  // 【7小節目】
  {576, 96, 77, 96, 96, 0}, // [3] F5

  // 【9小節目】
  {768, 96, 79, 96, 96, 0}, // [4] G5

  // 【11小節目】
  {960, 96, 81, 96, 96, 0}, // [5] A5

  // 【13小節目】
  {1152, 96, 83, 96, 96, 0}, // [6] B5

};





// int[][] Note;
