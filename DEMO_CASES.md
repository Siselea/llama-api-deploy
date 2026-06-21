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
```sql
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
```

**2. 查询某个用户所有帖子的被点赞总数**

方案 A：直接统计（推荐）

```sql
-- :target_user_id 为目标用户ID
SELECT COUNT(*) AS total_likes
FROM post_likes pl
JOIN posts p ON pl.post_id = p.post_id
WHERE p.user_id = :target_user_id;
```

方案 B：利用缓存字段

```
sql
SELECT SUM(p.like_count) AS total_likes
FROM posts p
WHERE p.user_id = :target_user_id;
```

3. 性能建议

高并发点赞：业务层使用乐观锁 + 事务，或利用唯一索引插入。

大规模读查询：对 posts.like_count 使用 Redis 缓存或物化视图。

统计报表：定时批处理聚合数据，写入统计表。

## 案例 5：逻辑推理 — 三盏灯开关
**问题：**

一个房间里有三盏灯，门外有三个开关，每个开关控制其中一盏灯。你只能进房间一次，如何确定哪个开关控制哪盏灯？

**回答：**
利用灯泡发热的时间差。

先打开开关 A，等待几分钟让灯泡变热。

关闭开关 A，立即打开开关 B，开关 C 保持关闭。

进入房间检查：

|灯泡状态	| 对应开关|
|------|------|
|亮着 | B|
|热但熄灭	| A|
|冷且熄灭	| C|
原理：A 曾打开使灯泡发热，B 当前点亮，C 从未打开。一次进门即可确定全部对应关系。

## 案例 6：翻译 — 格言翻译与文化差异 
**问题：**
请将这句话翻译成三种不同语言，并讨论每种翻译的风格选择：'Simplicity is the ultimate sophistication. - Leonardo da Vinci'

**回答：**

|语言	| 翻译版本	| 风格说明|
|------|------|------|
|法语	| « La simplicité est la sophistication ultime. – Léonard de Vinci »	| “simplicité” 为常见对应词；“ultime” 倒装保持韵律；署名按法语传统。|
西班牙语	| « La simplicidad es la máxima sofisticación. – Leonardo da Vinci »	| “máxima” 强调极致；“sofisticación” 更诗性；署名保留原拼写以显学术。|
德语	| « Die Einfachheit ist die ultimative Raffinesse. – Leonardo da Vinci »	| “Einfachheit” 贴合哲学内涵；“ultimative” 增添文学色彩；署名保留原样。|
细节讨论：

原文拼写错误（simplicity）在译文中均使用正确拼写，避免将错误带入目标语言。

作者署名处理上，法语、西班牙语采用当地传统，德语保留原始拼写以保证学术连贯性。

所有翻译均保持“X是Y”的对称结构，兼顾哲学意味与各语言文化习惯。

## 案例 7：逻辑推理 — 证明根号3无理
**问题：**
证明根号3也是无理数，并讨论如何推广到任意非完全平方数。

**回答：**
证明 √3 是无理数
假设 √3 = p/q，其中 p,q 互质。平方得 3q² = p²。
于是 p² 能被3整除，进而 p 能被3整除。设 p = 3k，代入得 3q² = 9k² ⇒ q² = 3k²。
同理 q 也能被3整除，与 p,q 互质矛盾。故 √3 是无理数。

推广到任意非完全平方数
结论：对整数 n > 1，若 n 不是完全平方数，则 √n 是无理数。

质因子分解法：若 √n = p/q（最简），则 n q² = p²。左边每个质因子的指数为 e_i + 偶数，右边全为偶数。若某 e_i 为奇数则矛盾，故所有 e_i 必为偶数，即 n 为完全平方。逆否命题即得证。

无限下降法：假设 √n = p/q，可构造更小的整数 m < n 使 √m 也为有理数，与最小性矛盾。

代数论视角：√n 是有理数则必为整数，故 n 为完全平方。
因此，任何非完全平方整数的平方根均为无理数。

## 案例 8：摘要 — 新能源汽车进展
**问题：**
请用300字左右简要介绍'新能源汽车发展'这一科技领域的最新进展，并提炼3个关键趋势和2个潜在挑战。

**回答：**
新能源汽车（NEV）技术正从“续航”向“综合体验”迈进。2024‑25年，固态电池与高能量密度材料实现小批量商业化；车联网通过5G/6G与云端AI结合，实现精准预测充电和路径规划；V2G模式与共享出行快速扩散。三大关键趋势：

固态/高能量密度电池：安全性提升，续航突破600‑800 km；

车网互联与V2G：车辆成为分布式储能节点，促进能源管理；

共享+智能化生态：云平台实现多车型协同运营与无感充电。

两大潜在挑战：
① 供应链与稀有资源瓶颈——锂、钴等价格波动，产能受限；
② 标准化与互操作性缺失——充电接口、软件协议不统一，影响用户体验。

总体来看，新能源汽车正向多维度生态系统转型，固态电池与车网协同是突破关键，而供应链韧性与标准化需同步提升。

## 案例 9：SQL — 递归查询下属
**问题：**
员工表 employee (id, name, manager_id)，请递归查询某个员工的所有下属（包括间接下属）。

**回答：**

下面给出几种主流数据库（MySQL 8+ / PostgreSQL / SQL Server / Oracle）下的递归查询示例，任选其一即可得到 某个员工的所有下属（包括间接下属）。

表结构 
 ```sql
 CREATE TABLE employee (
     id          INT PRIMARY KEY,
     name        VARCHAR(50),
     manager_id  INT NULL   -- 上级的 id，根节点为 NULL
 );
 ```

1. MySQL 8+ / PostgreSQL / SQL Server（递归 CTE）

```sql
传入要查询的上级员工 id，例如 :emp_id = 5
WITH RECURSIVE subordinates AS (
    -- 第一步：直接下属
    SELECT id, name, manager_id
    FROM employee
    WHERE manager_id = :emp_id

    UNION ALL

    -- 后续步骤：把刚得到的子级再往下找
    SELECT e.id, e.name, e.manager_id
    FROM employee e
    JOIN subordinates s ON e.manager_id = s.id
)
SELECT id, name
FROM subordinates;
```

说明  
`:emp_id` 为你想查询的员工 id。  
 递归 CTE 会把所有层级的下属一次性拉出来。  
 如果你还想把根节点本身也包含进来，只需把起始行改成 `WHERE id = :emp_id`，再在后面加上 `UNION ALL SELECT ... FROM employee WHERE manager_id = s.id` 即可。

 2. Oracle（CONNECT BY）

```sql
-- 传入要查询的上级员工 id，例如 :emp_id = 5
SELECT id, name
FROM   employee
START WITH id = :emp_id          -- 从根节点开始
CONNECT BY PRIOR manager_id = id; -- 子行的 manager_id 等于父行的 id
```

说明
 `PRIOR` 表示“上一层”的列。  
这条语句会返回根节点本身以及所有后代（直接、间接）下属。  


 3. 如果你想得到层级深度或路径

```sql
-- MySQL/PostgreSQL/SQL Server 示例
WITH RECURSIVE subordinates AS (
    SELECT id, name, manager_id, 1 AS lvl, CAST(id AS CHAR(2000)) AS path
    FROM employee
    WHERE manager_id = :emp_id

    UNION ALL

    SELECT e.id, e.name, e.manager_id,
           s.lvl + 1,
           CONCAT(s.path, '->', e.id)
    FROM employee e
    JOIN subordinates s ON e.manager_id = s.id
)
SELECT id, name, lvl, path
FROM subordinates;
```

 `lvl` 表示从根节点起算的层级（直接下属为 1）。  
 `path` 给出完整路径，方便调试。


 4. 防止循环引用

如果业务中可能出现 环形（A 的 manager_id 指向 B，而 B 又指向 A），递归查询会死循环。可以在 CTE 中加上已访问集合：

```sql
WITH RECURSIVE subordinates AS (
    SELECT id, name, manager_id, CAST(id AS CHAR(2000)) AS visited
    FROM employee
    WHERE manager_id = :emp_id

    UNION ALL

    SELECT e.id, e.name, e.manager_id,
           CONCAT(s.visited, ',', e.id)
    FROM employee e
    JOIN subordinates s ON e.manager_id = s.id
    WHERE FIND_IN_SET(e.id, s.visited) = 0   -- MySQL 示例
)
SELECT id, name
FROM subordinates;
```

 对于 PostgreSQL/SQL Server 可改用 `NOT EXISTS (SELECT 1 FROM string_to_array(s.visited, ',') t(val) WHERE t.val = e.id)` 等方式。

 小结

- **MySQL/PostgreSQL/SQL Server** → 用递归 CTE (`WITH RECURSIVE …`)  
- **Oracle** → 用 `CONNECT BY PRIOR`  
- 只要把起始条件改成 `WHERE manager_id = :emp_id`（或 `START WITH id = :emp_id`）即可得到所有下属。  

你可以直接把上述代码粘到对应数据库里，替换 `:emp_id` 为想查询的员工 id，即可获得该员工的全部子级（包括间接）。祝编码愉快 

