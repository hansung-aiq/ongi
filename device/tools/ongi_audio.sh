#!/system/bin/sh
# [온기] 오디오 도우미 (A안, 11/5)
# 앱(Android)에서는 USB 사운드카드 소리가 안 나서(퀄컴 USB 오프로드), root 권한의 tinyplay/tinycap으로 대신 튼다.
# 앱은 요청 파일만 쓰고, 이 도우미가 실제로 틀거나 녹음한 뒤 결과 파일을 남긴다.
#
# 띄우기 (맥, 보드 재부팅마다 한 번):
#   adb root
#   adb push device/tools/ongi_audio.sh /data/local/tmp/ongi/
#   adb shell "nohup sh /data/local/tmp/ongi/ongi_audio.sh > /data/local/tmp/ongi/audio.log 2>&1 &"
# 확인: adb shell cat /data/local/tmp/ongi/audio/alive   (1초마다 시각이 바뀌면 살아 있음)
# 끄기: adb shell "pkill -f ongi_audio.sh"
#
# 요청 (앱이 씀, 한 줄)
#   play.req : 틀 wav 경로 (48kHz 스테레오 16비트)
#   rec.req  : 녹음 초 (예: 5) → rec.wav (48kHz 모노 16비트)
#   stop.req : 내용 없음. 지금 틀거나 녹음하는 것을 멈춤
# 결과 (도우미가 씀)
#   play.done / rec.done : "ok" 또는 "error <이유>"
#   alive : 마지막으로 살아 있던 시각(초)

D=/data/local/tmp/ongi/audio
mkdir -p $D
chmod 777 $D
rm -f $D/*.req $D/*.done

# USB 사운드카드 번호 (없으면 빈 값)
usb_card() {
    grep -i "usb" /proc/asound/cards | head -1 | sed 's/^ *\([0-9]*\).*/\1/'
}

# 틀거나 녹음하는 동안에도 stop.req와 alive를 본다. 멈출 때는 INT(tinycap이 wav 머리를 마무리함). 끝나면 종료 코드를 돌려준다
run_wait() {
    "$@" &
    P=$!
    while kill -0 $P 2>/dev/null; do
        date +%s > $D/alive
        if [ -f $D/stop.req ]; then rm -f $D/stop.req; kill -INT $P 2>/dev/null; echo "멈춤 $(date)"; fi
        sleep 0.1
    done
    wait $P
}

echo "온기 오디오 도우미 시작 $(date)"
while true; do
    date +%s > $D/alive
    chmod 666 $D/alive 2>/dev/null

    if [ -f $D/stop.req ]; then
        rm -f $D/stop.req
        echo "멈춤(틀던 것 없음) $(date)"
    fi

    if [ -f $D/play.req ]; then
        F=$(cat $D/play.req); rm -f $D/play.req
        C=$(usb_card)
        if [ -z "$C" ]; then
            echo "error 사운드카드 없음" > $D/play.done
        elif [ ! -f "$F" ]; then
            echo "error 파일 없음 $F" > $D/play.done
        else
            echo "재생: $F (카드 $C)"
            run_wait tinyplay "$F" -D $C -d 0 > $D/play.out 2>&1
            R=$?
            if [ $R -eq 0 ]; then echo "ok" > $D/play.done; else echo "error tinyplay $R $(tail -1 $D/play.out)" > $D/play.done; fi
        fi
        chmod 666 $D/play.done
    fi

    if [ -f $D/rec.req ]; then
        S=$(cat $D/rec.req); rm -f $D/rec.req
        C=$(usb_card)
        rm -f $D/rec.wav
        if [ -z "$C" ]; then
            echo "error 사운드카드 없음" > $D/rec.done
        else
            echo "녹음: ${S}초 (카드 $C)"
            run_wait tinycap $D/rec.wav -D $C -d 0 -c 1 -r 48000 -b 16 -T $S > $D/rec.out 2>&1
            if [ -s $D/rec.wav ]; then chmod 666 $D/rec.wav; echo "ok" > $D/rec.done; else echo "error tinycap $(tail -1 $D/rec.out)" > $D/rec.done; fi
        fi
        chmod 666 $D/rec.done
    fi

    sleep 0.1
done
