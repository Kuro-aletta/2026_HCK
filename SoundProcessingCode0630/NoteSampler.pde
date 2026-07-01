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
      switch (timbre) {
        case "Flute": case "Flute2":
          player.PlayFlute(pitch, duration, startVelocity, endVelocity, 1.0f);
          break;
        case "Strings":
          player.PlayStrings(pitch, duration, startVelocity, endVelocity, 1.0f);
          break;
        case "Piano":
          player.PlayPiano(pitch, duration, startVelocity, 1.0f);
          break;
        case "Drum":
          /*
          if (pitch == 60) {
            player.PlayKick(startVelocity, 1.0f);
          } else if (pitch == 61) {
            player.PlaySnare(startVelocity, 1.0f);
          } else if (pitch == 62) {
            player.PlayHiHat(startVelocity, 1.0f);
          } else if (pitch == 63) {
            player.PlaySnare2(startVelocity, 1.0f);
          } else if (pitch == 64) {
            player.PlayHiHat2(startVelocity, 1.0f);
          }*/
          int a = int(pitch) % 12;
          if (a == 0)      player.PlayKick(startVelocity, 1.0f);
          else if (a == 1) player.PlaySnare(startVelocity, 1.0f);
          else if (a == 2) player.PlayHiHat(startVelocity, 1.0f);
          else if (a == 3) player.PlaySnare2(startVelocity, 1.0f);
          else if (a == 4) player.PlayHiHat2(startVelocity, 1.0f);
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
  {0, 1, 60, 80, 80}, // [0] C4
  {12, 1, 64, 80, 80}, // [1] E4
  {24, 1, 63, 80, 80}, // [2] D#4
  {24, 1, 60, 80, 80}, // [3] C4
  {36, 1, 64, 80, 80}, // [4] E4
  {48, 1, 60, 80, 80}, // [5] C4
  {60, 1, 64, 80, 80}, // [6] E4
  {72, 1, 63, 80, 80}, // [7] D#4
  {72, 1, 60, 80, 80}, // [8] C4
  {84, 1, 64, 80, 80}, // [9] E4

  // 【2小節目】
  {96, 1, 60, 80, 80}, // [10] C4
  {108, 1, 64, 80, 80}, // [11] E4
  {120, 1, 63, 80, 80}, // [12] D#4
  {120, 1, 60, 80, 80}, // [13] C4
  {132, 1, 64, 80, 80}, // [14] E4
  {144, 1, 60, 80, 80}, // [15] C4
  {156, 1, 64, 80, 80}, // [16] E4
  {168, 1, 63, 80, 80}, // [17] D#4
  {168, 1, 60, 80, 80}, // [18] C4
  {180, 1, 64, 80, 80}, // [19] E4
  {186, 1, 64, 48, 80}, // [20] E4

  // 【3小節目】
  {192, 1, 60, 80, 80}, // [21] C4
  {204, 1, 64, 80, 80}, // [22] E4
  {216, 1, 63, 80, 80}, // [23] D#4
  {216, 1, 60, 80, 80}, // [24] C4
  {228, 1, 64, 80, 80}, // [25] E4
  {240, 1, 60, 80, 80}, // [26] C4
  {252, 1, 64, 80, 80}, // [27] E4
  {264, 1, 63, 80, 80}, // [28] D#4
  {264, 1, 60, 80, 80}, // [29] C4
  {276, 1, 64, 80, 80}, // [30] E4

  // 【4小節目】
  {288, 1, 60, 80, 80}, // [31] C4
  {300, 1, 64, 80, 80}, // [32] E4
  {312, 1, 63, 80, 80}, // [33] D#4
  {312, 1, 60, 80, 80}, // [34] C4
  {324, 1, 64, 80, 80}, // [35] E4
  {336, 1, 60, 80, 80}, // [36] C4
  {348, 1, 64, 80, 80}, // [37] E4
  {360, 1, 63, 80, 80}, // [38] D#4
  {360, 1, 60, 64, 80}, // [39] C4
  {366, 1, 63, 48, 80}, // [40] D#4
  {372, 1, 63, 48, 80}, // [41] D#4
  {372, 1, 60, 64, 80}, // [42] C4
  {372, 1, 64, 80, 80}, // [43] E4
  {378, 1, 63, 64, 80}, // [44] D#4

  // 【5小節目】
  {384, 1, 60, 80, 80}, // [45] C4
  {396, 1, 64, 80, 80}, // [46] E4
  {408, 1, 63, 80, 80}, // [47] D#4
  {408, 1, 60, 80, 80}, // [48] C4
  {420, 1, 64, 80, 80}, // [49] E4
  {432, 1, 60, 80, 80}, // [50] C4
  {444, 1, 64, 80, 80}, // [51] E4
  {456, 1, 63, 80, 80}, // [52] D#4
  {456, 1, 60, 80, 80}, // [53] C4
  {468, 1, 64, 80, 80}, // [54] E4

  // 【6小節目】
  {480, 1, 60, 80, 80}, // [55] C4
  {492, 1, 64, 80, 80}, // [56] E4
  {504, 1, 63, 80, 80}, // [57] D#4
  {504, 1, 60, 80, 80}, // [58] C4
  {516, 1, 64, 80, 80}, // [59] E4
  {528, 1, 60, 80, 80}, // [60] C4
  {540, 1, 64, 80, 80}, // [61] E4
  {552, 1, 63, 80, 80}, // [62] D#4
  {552, 1, 60, 80, 80}, // [63] C4
  {564, 1, 64, 80, 80}, // [64] E4
  {570, 1, 64, 48, 80}, // [65] E4

  // 【7小節目】
  {576, 1, 60, 80, 80}, // [66] C4
  {588, 1, 64, 80, 80}, // [67] E4
  {600, 1, 63, 80, 80}, // [68] D#4
  {600, 1, 60, 80, 80}, // [69] C4
  {612, 1, 64, 80, 80}, // [70] E4
  {624, 1, 60, 80, 80}, // [71] C4
  {636, 1, 64, 80, 80}, // [72] E4
  {648, 1, 63, 80, 80}, // [73] D#4
  {648, 1, 60, 80, 80}, // [74] C4
  {660, 1, 64, 80, 80}, // [75] E4

  // 【8小節目】
  {672, 1, 60, 80, 80}, // [76] C4
  {672, 1, 63, 80, 80}, // [77] D#4
  {684, 1, 64, 80, 80}, // [78] E4
  {696, 1, 63, 80, 80}, // [79] D#4
  {696, 1, 60, 80, 80}, // [80] C4
  {708, 1, 64, 80, 80}, // [81] E4
  {720, 1, 60, 80, 80}, // [82] C4
  {720, 1, 63, 80, 80}, // [83] D#4
  {732, 1, 64, 80, 80}, // [84] E4
  {744, 1, 63, 80, 80}, // [85] D#4
  {744, 1, 60, 64, 80}, // [86] C4
  {750, 1, 63, 48, 80}, // [87] D#4
  {756, 1, 63, 48, 80}, // [88] D#4
  {756, 1, 64, 80, 80}, // [89] E4
  {762, 1, 63, 64, 80}, // [90] D#4
};
