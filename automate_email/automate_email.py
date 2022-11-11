import pandas as pd
import yagmail

df = pd.read_csv("danh_sach.csv")

for index, row in df.iterrows():
    # Sử dụng các thuộc tính trong row để chèn vào content và subject
    # Ví dụ: name = row["ho_ten"]

    yag = yagmail.SMTP('your-email', 'app-password')
    subject = "subject"
    contents = [
        'This is the body, and here is just text http://somedomain/image.png',
        'You can find an audio file attached.'
    ]
    yag.send('student-email', subject, contents)
