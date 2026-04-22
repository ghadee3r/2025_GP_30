# main.py
# TRIPLE TRIGGER: TIGHT FACE MEMORY (STRICT FILTER)
import sensor, time, ml, uos, gc, image, math
from pyb import UART

print("="*50)
print("RUNNING: TRIPLE HEARTBEAT SYNC MONITOR")
print("="*50)

uart = UART(1, 115200, timeout_char=1000)

def send_event(msg):
    try:
        uart.write(msg + "\n")
    except Exception:
        pass

sensor.reset()
sensor.set_contrast(3)
sensor.set_gainceiling(16)
sensor.set_framesize(sensor.HQVGA)      # 240x160
sensor.set_pixformat(sensor.RGB565)
sensor.skip_frames(time=2000)
print("Camera Ready: 240x160 RGB Wide")

# 1. LOAD SLEEP MODEL
try:
    net_sleep = ml.Model("sleep.tflite", load_to_fb=False)
    sleep_labels = [line.rstrip("\n") for line in open("sleep_labels.txt")]
    print("Sleep Model Loaded!")
except Exception as e:
    print("Sleep Error:", e)
    sleep_labels = ["awake", "sleep"]

# 2. LOAD PHONE MODEL (FOMO)
try:
    net_phone = ml.Model("phone.tflite", load_to_fb=False)
    print("Phone Model Loaded!")
except Exception as e:
    print("Phone Error:", e)

# 3. LOAD PRESENCE MODEL
try:
    face_cascade = image.HaarCascade("/rom/haarcascade_frontalface.cascade", stages=25)
    print("Presence Model Loaded!")
except Exception as e:
    print("Presence Error:", e)

sleep_index = -1
awake_index = -1
for i, label in enumerate(sleep_labels):
    if "sleep" in label.lower(): sleep_index = i
    if "awake" in label.lower(): awake_index = i

min_confidence = 0.75
threshold_list = [(math.ceil(min_confidence * 255), 255)]

def fomo_post_process(model, inputs, outputs):
    ob, oh, ow, oc = model.output_shape[0]
    x_scale = inputs[0].roi[2] / ow
    y_scale = inputs[0].roi[3] / oh
    scale = min(x_scale, y_scale)
    x_offset = ((inputs[0].roi[2] - (ow * scale)) / 2) + inputs[0].roi[0]
    y_offset = ((inputs[0].roi[3] - (ow * scale)) / 2) + inputs[0].roi[1]
    l = [[] for i in range(oc)]

    for i in range(oc):
        img_out = image.Image(outputs[0][0, :, :, i] * 255.0)
        blobs = img_out.find_blobs(threshold_list, x_stride=1, y_stride=1, area_threshold=1, pixels_threshold=1)
        for b in blobs:
            rect = b.rect()
            x, y, w, h = rect
            score = (img_out.get_statistics(thresholds=threshold_list, roi=rect).l_mean() / 255.0)
            x = int((x * scale) + x_offset)
            y = int((y * scale) + y_offset)
            w = int(w * scale)
            h = int(h * scale)
            l[i].append((x, y, w, h, score))
    return l

SLEEP_TH = 0.75
AWAKE_TH = 0.70

SLEEP_CONFIRM = 10
AWAKE_CONFIRM = 5
ABSENT_CONFIRM = 5
PRESENT_CONFIRM = 3
PHONE_CONFIRM = 4
NOPHONE_CONFIRM = 3

sleep_streak = 0; awake_streak = 0
absent_streak = 0; present_streak = 0
phone_streak = 0; nophone_streak = 0

sleep_state = "AWAKE"
presence_state = "PRESENT"
phone_state = "PHONE_OFF"

# FACE MEMORY VARIABLES
saved_face_box = None
face_memory_timer = 0

clock = time.clock()
frame_count = 0

send_event("SYSTEM_READY")

while True:
    clock.tick()
    frame_count += 1

    img = sensor.snapshot()

    # 1. Sleep Check
    try:
        predictions = net_sleep.predict([img])[0].flatten().tolist()
        sleep_p = predictions[sleep_index]
        awake_p = predictions[awake_index]
    except Exception as e:
        if frame_count % 30 == 0: print("Sleep processing error:", e)
        sleep_p = 0; awake_p = 1

    # 2. Presence Check & Face Memory
    is_present = False
    try:
        faces = img.find_features(face_cascade, threshold=0.3, scale_factor=1.15)
        if len(faces) > 0:
            is_present = True
            saved_face_box = faces[0]
            face_memory_timer = 5
        elif face_memory_timer > 0:
            is_present = True
            face_memory_timer -= 1
        else:
            saved_face_box = None
    except Exception as e:
        if frame_count % 30 == 0: print("Presence processing error:", e)
        is_present = True

    # Draw the Blue "No-Phone Zone" (Tight fit)
    ignore_zone = None
    if saved_face_box:
        fx, fy, fw, fh = saved_face_box
        # Tight 10-pixel buffer
        ignore_zone = (fx - 10, fy - 10, fw + 20, fh + 20)
        img.draw_rectangle(ignore_zone, color=(0, 0, 255), thickness=2)

    # 3. Phone Check
    is_phone = False
    try:
        for i, detection_list in enumerate(net_phone.predict([img], callback=fomo_post_process)):
            if i == 0: continue

            for x, y, w, h, score in detection_list:
                center_x = math.floor(x + (w / 2))
                center_y = math.floor(y + (h / 2))

                # The Strict Overlap Filter
                is_on_face = False
                if ignore_zone:
                    ix, iy, iw, ih = ignore_zone
                    if (ix < center_x < ix + iw) and (iy < center_y < iy + ih):
                        # If it is inside the face zone, strictly ignore it.
                        is_on_face = True

                if not is_on_face:
                    is_phone = True
                    img.draw_circle((center_x, center_y, 15), color=(255, 0, 0), thickness=2)
                    break
    except Exception as e:
        pass

    # --- Update Streaks ---
    if sleep_p >= SLEEP_TH:
        sleep_streak += 1; awake_streak = 0
    elif awake_p >= AWAKE_TH:
        awake_streak += 1; sleep_streak = 0
    else:
        sleep_streak = max(0, sleep_streak - 1); awake_streak = max(0, awake_streak - 1)

    if is_present:
        present_streak += 1; absent_streak = 0
    else:
        absent_streak += 1; present_streak = 0

    if is_phone:
        phone_streak += 1; nophone_streak = 0
    else:
        nophone_streak += 1; phone_streak = 0

    # --- State Machine ---
    if sleep_streak >= SLEEP_CONFIRM: sleep_state = "SLEEPING"
    if awake_streak >= AWAKE_CONFIRM: sleep_state = "AWAKE"

    if absent_streak >= ABSENT_CONFIRM: presence_state = "ABSENT"
    if present_streak >= PRESENT_CONFIRM: presence_state = "PRESENT"

    if phone_streak >= PHONE_CONFIRM: phone_state = "PHONE_ON"
    if nophone_streak >= NOPHONE_CONFIRM: phone_state = "PHONE_OFF"

    # HEARTBEAT
    if frame_count % 5 == 0:
        msg = f"SYNC:{sleep_state}:{presence_state}:{phone_state}"
        send_event(msg)
        print(msg)
