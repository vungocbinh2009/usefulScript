import pandas as pd
from mimesis.schema import Field, Schema
_ = Field()
# Cấu trúc của bảng dữ liệu.
description = (
   lambda: {
       'name': _('text.word'),
       'timestamp': _('timestamp', posix=False),
       'content_type': _('content_type'),
       'emoji': _('emoji'),
       'http_status_code': _('http_status_code'),
       'param1': _('dna_sequence'),
       'param2': _('rna_sequence')
   }
)
schema = Schema(schema=description)
# Tạo data frame có 1000 hàng
data_frame = pd.DataFrame(schema.create(iterations=1000))
data_frame.to_excel("fake_data.xlsx")

# Tài liệu đọc thêm: https://mimesis.name/en/master/index.html
