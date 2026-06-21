# API 案例演示

## 案例 1：翻译 — 产品本地化
**问题**：  
将下面的中文产品介绍翻译成英文和日文，并做本地化处理：'Innovation distinguishes between a leader and a follower. - Steve Jobs'

**回答**：  
English (localized)  
“Innovation is what separates a leader from a follower.” – Steve Jobs  

Japanese (localized)  
「イノベーションこそ、リーダーとフォロワーを分けるものです。」– スティーブ・ジョブズ

---

## 案例 2：摘要 — 合成生物学进展
**问题**：  
请用300字左右简要介绍'合成生物学'这一科技领域的最新进展，并提炼3个关键趋势和2个潜在挑战。

**回答**：  
合成生物学（Synthetic Biology）是把工程原理与分子生物学结合，构建可编程的生命系统。近年技术突破集中在三方面：① AI+基因编辑——深度学习模型预测CRISPR‑Cas9切割效率和脱靶效应，使得细胞内逻辑门、代谢通路可在数周内完成迭代优化；② 细胞外蛋白合成平台——利用核糖体机与人工翻译体系，实现高通量定制药物、酶及疫苗原料，缩短研发周期；③ 最小化细胞构建——通过基因组精简和模块重组，获得具有可控代谢网络的最小细胞工厂，用于生物燃料与化学品生产。

关键趋势

- AI驱动的自动化设计：从基因序列到代谢通路，全程由机器学习引导，大幅减少试错成本。
- 新型底盘细胞开发：非模式微生物（如嗜极菌、酵母）被工程化，拓展工业与环保应用场景。
- 标准化与模块化：基因元件库和组装标准的统一，使“即插即用”式生物制造成为可能。

潜在挑战  
① 生物安全与伦理：人工生命体的意外释放或滥用风险，需建立全球监管与风险评估体系；  
② 规模化与成本：从实验室到工业发酵，产量、稳定性和纯化工艺仍面临经济可行性瓶颈。

---

## 案例 3：逻辑推理 — 三位数立方和
**问题**：  
一个数字的各位立方和等于它本身，找出所有三位数中满足此性质的数。

**回答**：  
满足“各位立方和等于本身”的三位数有四个：153, 370, 371, 407。

证明思路  
设三位数为 `abc` = 100a + 10b + c，其中 a ∈ {1,…,9}，b,c ∈ {0,…,9}。  
要求：100a + 10b + c = a³ + b³ + c³。

1. 上界与下界  
   最大立方和 9³×3 = 2187 > 999，存在可能；最小三位数100，最小立方和1³+0³+0³=1 < 100，需逐个检验。

2. 化简与枚举  
   等式变形为 a³ - 100a + b³ - 10b + c³ - c = 0，枚举得仅以下四组成立：

   | a | b | c |
   |---|---|---|
   | 1 | 5 | 3 |
   | 3 | 7 | 0 |
   | 3 | 7 | 1 |
   | 4 | 0 | 7 |

3. 验证  
   - 153 = 1³ + 5³ + 3³ = 1 + 125 + 27  
   - 370 = 3³ + 7³ + 0³ = 27 + 343 + 0  
   - 371 = 3³ + 7³ + 1³ = 27 + 343 + 1  
   - 407 = 4³ + 0³ + 7³ = 64 + 0 + 343  

结论：所有三位数中，153、370、371、407 是唯一满足性质的数。

---

## 案例 4：SQL — 点赞系统数据库设计
**问题**：  
请设计一个社交媒体的点赞系统数据库模型，并写出查询某用户帖子被点赞总数的SQL。

**回答**：  

**1. 数据库模型**（以 PostgreSQL / MySQL 为例）

| 表名 | 主键 | 说明 |
|------|------|------|
| users | user_id (BIGINT) | 用户基本信息 |
| posts | post_id (BIGINT) | 帖子内容 |
| post_likes | (post_id, user_id) | 点赞记录（复合主键防重复点赞） |

建表语句：
[```sql
-- users 表
CREATE TABLE users (
    user_id      BIGINT PRIMARY KEY,
    username     VARCHAR(50) NOT NULL UNIQUE,
    email        VARCHAR(100),
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- posts 表
CREATE TABLE posts (
    post_id      BIGINT PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content      TEXT,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    like_count   INT UNSIGNED DEFAULT 0   -- 可选：缓存点赞数
);

-- post_likes 表
CREATE TABLE post_likes (
    post_id      BIGINT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id      BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    liked_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (post_id, user_id),
    INDEX idx_post_likes_user (user_id),
    INDEX idx_post_likes_post (post_id)
);

**2. 查询某个用户所有帖子的被点赞总数**

**方案 A：直接统计（推荐）**

sql
-- :target_user_id 为目标用户ID
SELECT COUNT(*) AS total_likes
FROM post_likes pl
JOIN posts p ON pl.post_id = p.post_id
WHERE p.user_id = :target_user_id;

**方案 B：利用缓存字段**

sql
SELECT SUM(p.like_count) AS total_likes
FROM posts p
WHERE p.user_id = :target_user_id;

**3. 性能建议**

高并发点赞：业务层使用乐观锁 + 事务，或利用唯一索引插入。

大规模读查询：对 posts.like_count 使用 Redis 缓存或物化视图。

统计报表：定时批处理聚合数据，写入统计表。
