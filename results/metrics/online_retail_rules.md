# Luật kết hợp trên UCI Online Retail

Minsup **1%** (198 giỏ), minconf **50%**.

| Bước | Dòng hàng | Hóa đơn | Mã hàng |
|---|---:|---:|---:|
| Dữ liệu nguồn | 541909 | 25900 | 4070 |
| Sau khi lọc hóa đơn hủy, mã thiếu, số lượng và đơn giá | 530104 | 19960 | 3922 |
| Sau khi loại mã phí và điều chỉnh | 527794 | 19775 | 3914 |

Số dòng loại theo mã phí hoặc điều chỉnh: `AMAZONFEE`: 2, `B`: 1, `BANK CHARGES`: 12, `C2`: 141, `DOT`: 706, `M`: 321, `POST`: 1126, `m`: 1.

**Hóa đơn 536365.** Dòng gốc (mã × số lượng): 85123A × 6.0, 71053 × 6.0, 84406B × 8.0, 84029G × 6.0, 84029E × 6.0, 22752 × 2.0, 21730 × 6.0.
Giỏ theo thứ tự ID: 772, 1625, 2730, 2897, 2898, 2954, 3408.
Mã tương ứng: 21730, 22752, 71053, 84029E, 84029G, 84406B, 85123A.

**2007** itemset phổ biến và **956** luật đạt ngưỡng.

| Hạng | Vế trái | Vế phải | Giỏ chứa cả hai | Support | Confidence | Lift |
|---:|---|---|---:|---:|---:|---:|
| 1 | HERB MARKER ROSEMARY [22917] + HERB MARKER PARSLEY [22918] | HERB MARKER THYME [22916] | 203 | 1.0265% | 94.4186% | 78.7818 |
| 2 | HERB MARKER THYME [22916] | HERB MARKER ROSEMARY [22917] + HERB MARKER PARSLEY [22918] | 203 | 1.0265% | 85.654% | 78.7818 |
| 3 | HERB MARKER THYME [22916] + HERB MARKER PARSLEY [22918] | HERB MARKER ROSEMARY [22917] | 203 | 1.0265% | 95.3052% | 78.5275 |
| 4 | HERB MARKER ROSEMARY [22917] | HERB MARKER THYME [22916] + HERB MARKER PARSLEY [22918] | 203 | 1.0265% | 84.5833% | 78.5275 |
| 5 | HERB MARKER THYME [22916] + HERB MARKER BASIL [22920] | HERB MARKER ROSEMARY [22917] | 200 | 1.0114% | 95.2381% | 78.4722 |
| 6 | HERB MARKER ROSEMARY [22917] | HERB MARKER THYME [22916] + HERB MARKER BASIL [22920] | 200 | 1.0114% | 83.3333% | 78.4722 |
| 7 | HERB MARKER ROSEMARY [22917] + HERB MARKER BASIL [22920] | HERB MARKER THYME [22916] | 200 | 1.0114% | 93.4579% | 77.9802 |
| 8 | HERB MARKER THYME [22916] | HERB MARKER ROSEMARY [22917] + HERB MARKER BASIL [22920] | 200 | 1.0114% | 84.3882% | 77.9802 |
| 9 | HERB MARKER THYME [22916] | HERB MARKER ROSEMARY [22917] | 221 | 1.1176% | 93.2489% | 76.8332 |
| 10 | HERB MARKER ROSEMARY [22917] | HERB MARKER THYME [22916] | 221 | 1.1176% | 92.0833% | 76.8332 |
