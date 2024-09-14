import cv2
from ultralytics import YOLO
classNames = ["person", "bicycle", "car", "motorbike", "aeroplane", "bus", "train", "truck", "boat",
              "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
              "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella",
              "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite", "baseball bat",
              "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle", "wine glass", "cup",
              "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange", "broccoli",
              "carrot", "hot dog", "pizza", "donut", "cake", "chair", "sofa", "pottedplant", "bed",
              "diningtable", "toilet", "tvmonitor", "laptop", "mouse", "remote", "keyboard", "cell phone",
              "microwave", "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors",
              "teddy bear", "hair drier", "toothbrush"
              ]


def detect_objects_in_webcam1(model, object_name):
    # Open the webcam
    cap = cv2.VideoCapture(0)

    # Check if the webcam is opened successfully
    if not cap.isOpened():
        print("Error: Unable to open webcam")
        return
    while True:
        # Loop to continuously capture frames and perform object detection
        ret, frame = cap.read()
        if object_name != "":
            results = model(frame, classes=classNames.index(object_name))
        else:
            results = model(frame)

        for result in results:
            detection_count = result.boxes.shape[0]

            for i in range(detection_count):
                confidence = float(result.boxes.conf[i].item())
                if confidence >= 0.5:
                    cls = int(result.boxes.cls[i].item())
                    bounding_box = result.boxes.xyxy[i].cpu().numpy()
                    x = int(bounding_box[0])
                    y = int(bounding_box[1])
                    width = int(bounding_box[2] - x)
                    height = int(bounding_box[3] - y)
                    cv2.rectangle(frame, (int(x), int(y)), (int(x+width), int(y+height)), (255, 0, 255), 3)
                    cv2.putText(frame, result.names[cls], (int(x), int(y) - 10), cv2.FONT_HERSHEY_SIMPLEX, 1,
                                (255, 0, 0), 2)

        cv2.imshow('Objects Detected', frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            cap.release()
            cv2.destroyAllWindows()
            ask_for_input(model)
        elif cv2.waitKey(1) == 27:
            cap.release()
            cv2.destroyAllWindows()
            break


def ask_for_input(model):
    # Object name to detect
    object_name = input("Enter the object to detect: ")
    # Detect object in the webcam feed
    detect_objects_in_webcam1(model, object_name)

def main():
    # Load YOLOv8 model
    model = YOLO("yolov8n.pt")
    ask_for_input(model)


if __name__ == "__main__":
    main()




