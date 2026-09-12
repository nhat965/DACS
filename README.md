# Website thương mại điện tử mỹ phẩm

Đồ án cơ sở xây dựng website thương mại điện tử mỹ phẩm, tập trung vào trải nghiệm mua sắm dễ sử dụng và hệ thống gợi ý sản phẩm cá nhân hóa dựa trên nhu cầu và hành vi khách hàng.

## Cấu trúc source

Dự án được tổ chức theo hướng monorepo để nhóm có thể chia việc rõ ràng nhưng vẫn tích hợp được thành một hệ thống thống nhất.

```text
DACS/
  apps/
    web/                         # Website thương mại điện tử, UI khách hàng và admin
  services/
    recommendation-service/      # Hệ thống gợi ý sản phẩm
    chatbot-service/             # Chatbot tư vấn dựa trên dữ liệu hệ thống
    analytics-service/           # Phân tích dữ liệu, dashboard metrics
    stream-analytics-service/    # Xử lý sự kiện thời gian gần thực
  packages/
    shared-contracts/            # DTO, enum, schema dùng chung nếu cần
  contracts/
    openapi/                     # API contract giữa website và hệ thống bên trong
    events/                      # Event contract cho behavior tracking/streaming
  database/
    migrations/                  # SQL migration
    seeds/                       # Dữ liệu mẫu
    docs/                        # ERD, data dictionary, quy tắc dữ liệu
  datasets/
    product-catalog/             # Dataset sản phẩm mỹ phẩm
    raw/                         # Dữ liệu thô
    processed/                   # Dữ liệu đã làm sạch
  docs/
    architecture/                # Kiến trúc, phân công, luồng tích hợp
    phase-1/                     # Tài liệu Giai đoạn 1
```

Phần website có thể phát triển độc lập trong `apps/web`. Phần hệ thống bên trong như recommendation, chatbot, analytics, database và stream analytics được phát triển trong `services`, `database`, `datasets` và `contracts`. Hai phần liên kết với nhau thông qua REST API, event tracking và cơ sở dữ liệu đã thống nhất.

## 1. Thông tin đề tài

- Tên đề tài: Xây dựng website thương mại điện tử mỹ phẩm tích hợp hệ thống gợi ý sản phẩm lai cá nhân hóa và chatbot tư vấn dựa trên dữ liệu hệ thống
- Loại đồ án: Đồ án cơ sở
- Nhóm thực hiện: Nhóm 3
- Thành viên:
  - Trần Văn Nhật - 23010625
  - Nguyễn Huy Hiệp - 23010178
- Giảng viên hướng dẫn: Đặng Thị Thúy An

## 2. Mục tiêu

- Xây dựng website bán mỹ phẩm có giao diện trực quan, dễ thao tác.
- Hỗ trợ khách hàng tìm kiếm, lọc, xem, lựa chọn và đặt mua sản phẩm.
- Thu thập dữ liệu tương tác của khách hàng trong quá trình sử dụng website.
- Xây dựng hệ thống gợi ý lai kết hợp Knowledge-Based, Content-Based và Collaborative Filtering ở mức cơ bản.
- Điều chỉnh trọng số gợi ý theo mức độ dữ liệu của từng người dùng.
- Xây dựng chatbot tư vấn cơ bản dựa trên câu hỏi, thuộc tính, thành phần và công dụng được lưu trong hệ thống.

## 3. Phạm vi đồ án

### 3.1. Chức năng khách hàng

- Đăng ký, đăng nhập và quản lý tài khoản.
- Xem danh mục và chi tiết sản phẩm.
- Tìm kiếm và lọc theo danh mục, thương hiệu, giá, loại da và vấn đề da.
- Thêm sản phẩm vào danh sách yêu thích.
- Thêm, xóa và cập nhật sản phẩm trong giỏ hàng.
- Đặt hàng và thanh toán mô phỏng.
- Theo dõi lịch sử và trạng thái đơn hàng.
- Đánh giá sản phẩm sau khi mua.
- Nhận gợi ý sản phẩm cá nhân hóa.
- Trao đổi với chatbot tư vấn sản phẩm cơ bản.

### 3.2. Chức năng quản trị

- Đăng nhập và phân quyền quản trị viên.
- Quản lý sản phẩm, danh mục và thương hiệu.
- Quản lý tồn kho và trạng thái sản phẩm.
- Quản lý người dùng và đơn hàng.
- Theo dõi đánh giá sản phẩm.
- Xem dữ liệu tương tác phục vụ hệ thống gợi ý.

### 3.3. Ngoài phạm vi phiên bản cơ sở

- Chưa huấn luyện hoặc fine-tune mô hình ngôn ngữ lớn.
- Chưa triển khai RAG, Vector Search hoặc AI Agent nhiều bước.
- Chưa tích hợp thanh toán thật.
- Chưa triển khai Collaborative Filtering trên dữ liệu quy mô lớn.
- Chưa xây dựng hệ thống chẩn đoán bệnh da hoặc tư vấn thay thế chuyên gia y tế.

## 4. Kiến trúc dự kiến

```text
apps/web
    |
    | REST API + Behavior Events
    v
Backend API / API Gateway
    |
    +-- Ecommerce Modules
    |       +-- User/Auth
    |       +-- Product/Catalog
    |       +-- Cart/Order
    |
    +-- Internal System Services
            +-- Recommendation Service
            +-- Chatbot Service
            +-- Analytics Service
            +-- Stream Analytics Service
            +-- Database and Dataset Pipeline
```

Chatbot tư vấn cơ bản hoạt động bằng cách phân tích từ khóa hoặc lựa chọn của người dùng, truy vấn dữ liệu sản phẩm và tạo câu trả lời theo mẫu. Chatbot không tự tạo sản phẩm hoặc công dụng ngoài dữ liệu đã được kiểm duyệt.

## 5. Hệ thống gợi ý

### Knowledge-Based Recommendation

Gợi ý dựa trên thông tin người dùng cung cấp:

- Loại da.
- Vấn đề da.
- Mục tiêu chăm sóc.
- Danh mục mong muốn.
- Khoảng ngân sách.
- Thành phần quan tâm hoặc muốn tránh.

### Content-Based Recommendation

Gợi ý sản phẩm tương đồng với các sản phẩm người dùng đã xem, yêu thích, thêm vào giỏ hàng hoặc mua. Các thuộc tính được sử dụng gồm danh mục, thương hiệu, loại da, vấn đề da, thành phần, công dụng và khoảng giá.

### Collaborative Filtering

Trong phạm vi đồ án cơ sở, ưu tiên Item-Based Collaborative Filtering. Ví dụ: khách hàng quan tâm đến sản phẩm A thường quan tâm hoặc mua thêm sản phẩm B.

### Hybrid Scoring

```text
FinalScore(u, i) =
    alpha(u) * KBScore(u, i)
  + beta(u)  * CBScore(u, i)
  + gamma(u) * CFScore(u, i)
```

Trong đó:

```text
alpha(u) + beta(u) + gamma(u) = 1
```

Người dùng mới được ưu tiên Knowledge-Based. Khi số lượng và chất lượng hành vi tăng lên, Content-Based và Collaborative Filtering được tăng mức ảnh hưởng.

## 6. Dữ liệu hành vi

Các sự kiện cần ghi nhận:

- `view_product`: xem sản phẩm.
- `search_keyword`: tìm kiếm.
- `filter_used`: sử dụng bộ lọc.
- `click_recommendation`: click vào sản phẩm được gợi ý.
- `add_favorite`: thêm vào yêu thích.
- `add_to_cart`: thêm vào giỏ hàng.
- `remove_from_cart`: xóa khỏi giỏ hàng.
- `place_order`: đặt hàng.
- `review_product`: đánh giá sản phẩm.

Mỗi sự kiện nên lưu người dùng, sản phẩm, loại hành vi, giá trị tương tác, thời điểm và session nếu có.

## 7. Dữ liệu sản phẩm

Các trường dữ liệu tối thiểu:

- Mã và tên sản phẩm.
- Thương hiệu và danh mục.
- Giá, dung tích và tồn kho.
- Mô tả và công dụng.
- Thành phần INCI.
- Thành phần chính và công dụng của từng thành phần.
- Loại da phù hợp.
- Vấn đề da hỗ trợ.
- Mục tiêu chăm sóc.
- Kết cấu sản phẩm.
- Hướng dẫn sử dụng.
- Cảnh báo.
- Hình ảnh.
- Nguồn dữ liệu và ngày xác minh.

Nguồn ưu tiên là website chính thức của thương hiệu hoặc nhà phân phối chính thức. Dữ liệu từ sàn thương mại điện tử chỉ nên dùng để tham khảo hoặc đối chiếu khi được phép.

## 8. Công nghệ dự kiến

| Thành phần | Công nghệ dự kiến |
|---|---|
| Backend | Java Spring Boot |
| Frontend | React hoặc Thymeleaf |
| Database | MySQL local |
| API | REST API |
| Recommendation | Java hoặc Python service |
| Data processing | Python, Pandas, NumPy nếu cần |
| Database tool | MySQL Workbench hoặc Docker |

> Công nghệ có thể được điều chỉnh sau khi nhóm chốt kiến trúc và phân công triển khai.

## 9. Chạy dự án local

### Yêu cầu môi trường

- JDK 17 trở lên.
- Maven hoặc Gradle.
- Node.js và npm nếu sử dụng React.
- MySQL 8 trở lên hoặc Docker.
- Git.

### Cấu hình MySQL

Tạo database local:

```sql
CREATE DATABASE cosmetic_ecommerce
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```

Ví dụ cấu hình backend:

```properties
spring.datasource.url=jdbc:mysql://localhost:3306/cosmetic_ecommerce
spring.datasource.username=YOUR_DB_USER
spring.datasource.password=YOUR_DB_PASSWORD
```

Không commit mật khẩu, khóa bí mật hoặc thông tin cá nhân thật vào repository. Nên sử dụng file cấu hình local hoặc biến môi trường.

### Khởi chạy backend

```bash
./mvnw spring-boot:run
```

Trên Windows có thể dùng:

```powershell
./mvnw.cmd spring-boot:run
```

### Khởi chạy frontend

Nếu dự án sử dụng React:

```bash
npm install
npm run dev
```

Các lệnh trên là cấu hình dự kiến và sẽ được cập nhật theo cấu trúc source code thực tế.

## 10. Lộ trình thực hiện

1. Chốt yêu cầu, persona, hành trình khách hàng và phạm vi.
2. Thiết kế Use Case, Activity Diagram, kiến trúc và cơ sở dữ liệu.
3. Chuẩn bị Product Dataset và quy tắc chuẩn hóa.
4. Xây dựng giao diện và chức năng thương mại điện tử cốt lõi.
5. Xây dựng Behavior Tracking và User Profile.
6. Triển khai Knowledge-Based và Content-Based Recommendation.
7. Bổ sung Item-Based Collaborative Filtering ở mức cơ bản.
8. Xây dựng Hybrid Scoring và Dynamic Weight Engine.
9. Xây dựng chatbot tư vấn theo luật và dữ liệu sản phẩm.
10. Kiểm thử, đánh giá, hoàn thiện báo cáo và chuẩn bị demo.

## 11. Tiêu chí đánh giá

### Website

- Các luồng xem sản phẩm, giỏ hàng và đặt hàng hoạt động đầy đủ.
- Dữ liệu được kiểm tra hợp lệ.
- User và Admin được phân quyền đúng.
- Giao diện dễ sử dụng và hiển thị tốt trên các kích thước màn hình chính.

### Hệ thống gợi ý

- So sánh KB, CB, CF và mô hình Hybrid.
- Đánh giá bằng Precision@K, Recall@K và F1@K nếu có dữ liệu phù hợp.
- Có thể bổ sung Coverage, Diversity và tỷ lệ click vào sản phẩm gợi ý.
- Hiển thị được lý do sản phẩm được đề xuất.

### Chatbot

- Nhận diện được các nhu cầu phổ biến.
- Truy xuất đúng sản phẩm trong cơ sở dữ liệu.
- Giải thích dựa trên thành phần, công dụng và thuộc tính đã lưu.
- Không tự chẩn đoán bệnh, không cam kết hiệu quả điều trị và không bịa thông tin.

## 12. Hướng phát triển

Sau khi phiên bản cơ sở ổn định, hệ thống có thể được mở rộng bằng:

- RAG và Vector Search.
- AI Agent tư vấn mỹ phẩm nhiều bước.
- LLM chạy local hoặc cloud.
- Gợi ý routine chăm sóc da.
- Phân khúc khách hàng và dashboard phân tích nâng cao.
- Learning-to-Rank và tối ưu trọng số bằng Machine Learning.

## 13. Giấy phép và mục đích sử dụng

Đây là sản phẩm phục vụ mục đích học tập và nghiên cứu trong khuôn khổ đồ án. Dữ liệu sản phẩm cần được sử dụng đúng quyền, ghi rõ nguồn và không được xem là tư vấn y khoa.
