<#
.SYNOPSIS
    超高负载 AI API 压力测试 v11_final (兼容 PS 5.1)
#>
param(
    [ValidateNotNullOrEmpty()][string]$ApiUrl = "http://127.0.0.1:8070/v1/chat/completions",
    [string]$ApiKey = "",
    [ValidateRange(1, 720)][int]$TotalHours = 72,
    [ValidateRange(1, 32)][int]$Concurrency = 1,
    [switch]$SkipLongTexts,
    [string]$LogFile = "",
    [int]$MaxLogSizeMB = 100,
    [int]$StatsIntervalSec = 5
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Threading -ErrorAction SilentlyContinue

if (-not $LogFile) {
    $scriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path $MyInvocation.MyCommand.Path } else { Get-Location }
    $LogFile = Join-Path $scriptDir "stress_test_log.txt"
}
$logDir = Split-Path $LogFile -Parent
if ($logDir -and -not (Test-Path $logDir)) { $null = New-Item -ItemType Directory -Path $logDir -Force }

$startTime = Get-Date
$endTime = $startTime.AddHours($TotalHours)
$global:cancelTokenSource = New-Object System.Threading.CancellationTokenSource
$stopToken = $global:cancelTokenSource.Token

$queueCapacity = [Math]::Min($Concurrency * 200, 5000)
$script:taskQueue   = New-Object "System.Collections.Concurrent.BlockingCollection[psobject]" $queueCapacity
$script:resultQueue = New-Object "System.Collections.Concurrent.BlockingCollection[psobject]" ($queueCapacity * 2)
$script:logQueue    = New-Object "System.Collections.Concurrent.BlockingCollection[string]" ($queueCapacity * 10)

$script:successCount      = [long]0
$script:failCount         = [long]0
$script:totalElapsedUs    = [long]0
$script:totalCompTokens   = [long]0
$script:iteration         = [long]0
$script:latencyBufferSize = 20000
$script:latencyBuffer     = [double[]]::new($script:latencyBufferSize)
$script:latencyIndex      = 0
$script:latencyCount      = [long]0
$script:errorTypeCounts   = New-Object "System.Collections.Concurrent.ConcurrentDictionary[string, long]"

# ---------- 兼容 PS 5.1 的 HttpClient ----------
$script:sharedHandler = New-Object System.Net.Http.HttpClientHandler
$script:sharedHandler.MaxConnectionsPerServer = 200
[System.Net.ServicePointManager]::DefaultConnectionLimit = 200
[System.Net.ServicePointManager]::Expect100Continue = $false
$script:httpClient = New-Object System.Net.Http.HttpClient($script:sharedHandler, $false)
$script:httpClient.Timeout = [TimeSpan]::FromMinutes(3)

# ================== 动态题库（完整，同 v11_final） ==================
$langPool = @("Python", "JavaScript", "Go", "Rust", "C++", "Java", "TypeScript", "Kotlin", "Swift", "Ruby")
$algoPool = @("二分查找", "快速排序", "归并排序", "Dijkstra最短路径", "背包问题动态规划", "LRU缓存", "布隆过滤器", "A*寻路", "哈希表", "红黑树")
$appPool  = @("防抖函数", "节流函数", "深拷贝", "Promise.all实现", "事件总线", "虚拟滚动", "图片懒加载", "路由守卫", "国际化方案", "暗黑模式切换")
function New-CodePrompt {
    $templates = @(
        "请用 {0} 实现{1}算法，附带详细注释和复杂度分析。并讨论该算法在工程实践中的典型应用和局限性。",
        "用 {0} 编写一个{2}，给出完整实现和使用示例，并深入剖析其性能影响。",
        "在 {0} 中如何实现一个高效的{1}？请给出代码并解释关键优化点。",
        "用 {0} 设计一个{2}，需要包含错误处理和单元测试，并解释设计决策。",
        "详细解释 {0} 中的{1}原理，并用 {0} 给出一个完整的实现。"
    )
    $tpl = Get-Random $templates; $lang = Get-Random $langPool; $algo = Get-Random $algoPool; $app = Get-Random $appPool
    return ($tpl -f $lang, $algo, $app)
}
function New-ReasonPrompt {
    $templates = @(
        "甲、乙、丙三人中只有一人会游泳。甲说：我会；乙说：我不会；丙说：甲不会。如果三人中只有一人说了真话，那么谁会游泳？请逐步推理。",
        "一个房间里有三盏灯，门外有三个开关，每个开关控制其中一盏灯。你只能进房间一次，如何确定哪个开关控制哪盏灯？",
        "小明、小红、小刚分别来自北京、上海、广州。已知：(1)小明不是北京人；(2)小红不是上海人；(3)北京人比小明年龄大；(4)上海人比小红年龄小。请推断他们各自的籍贯。",
        "证明：根号2是无理数。请用反证法给出完整推导，并说明该证明在数学史上的意义。",
        "用数学归纳法证明：1 + 2 + ... + n = n(n+1)/2。请写出完整步骤并讨论应用。",
        "一个水池有两个进水管(A:3h满, B:2h满)和一个出水管(C:5h放完)，三管齐开多久注满？请建立方程求解。",
        "小明到达百米终点时小红跑了90米。若小明后退10米起跑，谁会先到终点？请用数学推导。",
        "证明根号3也是无理数，并讨论如何推广到任意非完全平方数。",
        "一个数字的各位立方和等于它本身，找出所有三位数中满足此性质的数。",
        "有五顶帽子三蓝两红，三人随机各戴一顶，每人能看到另两人帽子但看不到自己的。逐个问是否能猜出自己帽子颜色，前两人都说不能，第三人说能。请问第三人帽子颜色及推理过程。"
    )
    return Get-Random $templates
}
function New-TranslatePrompt {
    $srcTexts = @(
        "The measure of intelligence is the ability to change. - Albert Einstein",
        "Innovation distinguishes between a leader and a follower. - Steve Jobs",
        "Stay hungry, stay foolish. - Steve Jobs",
        "The best way to predict the future is to invent it. - Alan Kay",
        "Simplicity is the ultimate sophistication. - Leonardo da Vinci",
        "科技的真正意义在于让生活更美好。",
        "数字化转型已成为企业生存的必选项。",
        "本产品采用纳米级防水涂层，可在水深10米处正常工作30分钟，并已通过IP68认证。",
        "请将本文件翻译成英文和日文，并对英文版本进行本地化改写。",
        "The quick brown fox jumps over the lazy dog."
    )
    $templates = @(
        "将以下内容翻译成中文、日文和法文，并解释翻译中的文化差异：'{0}'",
        "将下面的中文产品介绍翻译成英文和日文，并做本地化处理：'{0}'",
        "请将这句话翻译成三种不同语言，并讨论每种翻译的风格选择：'{0}'"
    )
    $tpl = Get-Random $templates; $text = Get-Random $srcTexts
    return ($tpl -f $text)
}
function New-SummarizePrompt {
    $topics = @("人工智能伦理", "量子计算最新突破", "区块链在供应链的应用", "5G与物联网融合", "新能源汽车发展", "太空探索商业化", "元宇宙的未来", "生物打印器官", "脑机接口进展", "合成生物学")
    $t = Get-Random $topics
    return "请用300字左右简要介绍'{0}'这一科技领域的最新进展，并提炼3个关键趋势和2个潜在挑战。" -f $t
}
function New-ShortQAPrompt {
    $topics = @(
        @{ q="详细解释机器学习中的过拟合，以及如何通过正则化、交叉验证、早停和数据增强来避免。"; tok=3000 },
        @{ q="用简单比喻解释区块链，并深入讲解PoW、PoS共识机制、哈希指针和Merkle树如何保障不可篡改。"; tok=3500 },
        @{ q="解释微服务架构的优缺点，并与单体架构进行对比。"; tok=3000 },
        @{ q="什么是CAP定理？结合实际系统说明如何在一致性、可用性和分区容错性之间权衡。"; tok=3000 },
        @{ q="介绍Transformer模型的核心组件（自注意力、多头注意力、位置编码）及其工作原理。"; tok=4000 },
        @{ q="讨论容器技术（Docker）与虚拟机的区别，以及容器编排（Kubernetes）的核心概念。"; tok=3500 },
        @{ q="什么是SQL注入？如何防范？给出代码示例和防御措施。"; tok=2500 },
        @{ q="解释REST和GraphQL的区别，各自适合什么场景？"; tok=3000 },
        @{ q="讲解OAuth 2.0的授权流程，并比较授权码模式和客户端凭证模式。"; tok=3500 },
        @{ q="什么是WebAssembly？它如何提升Web应用性能？"; tok=3000 }
    )
    $item = Get-Random $topics
    return @{ prompt=$item.q; type="短问答"; max_tokens=$item.tok; temperature=0.8 }
}
function New-MediumPrompt {
    $topics = @(
        "人工智能如何改变医疗行业",
        "远程办公对团队协作的影响",
        "共享经济的未来发展趋势",
        "电动汽车对传统能源行业的冲击",
        "在线教育能否取代传统课堂",
        "社交媒体对青少年心理健康的影响",
        "智慧城市建设的挑战与机遇",
        "大数据在零售业的应用",
        "隐私保护与数据安全的平衡",
        "虚拟现实技术将如何改变娱乐产业"
    )
    $t = Get-Random $topics
    return "写一篇1000字左右的文章，主题是'{0}'，要求包含至少3个真实案例、数据分析和个人观点。" -f $t
}
function New-LongPrompt {
    $topics = @("被遗忘的星辰", "量子玫瑰", "时间移民", "意识上传", "硅基黎明", "最后的宇航员", "机械之心", "2049：仿生人", "星海归途", "永夜中的灯塔")
    $t = Get-Random $topics
    return "请你扮演一位科幻小说家，以'{0}'为题，写一个短篇科幻小说的开头（约1500字）。要求有世界观设定、人物出场和情节悬念，但**不需要写完整个故事**。不要重复段落，不要使用省略号填充内容。" -f $t
}
function New-RoleplayPrompt {
    $roles = @("资深职业规划师", "拥有自我意识的智能冰箱", "未来城市的市长", "AI伦理学家", "时间旅行者", "火星殖民地的第一批居民", "一本有魔法的书", "退役的机器人拳击手", "会说话的猫", "中世纪炼金术士")
    $role = Get-Random $roles
    if ($role -eq "资深职业规划师") {
        return "你现在是一位资深职业规划师，请为一个30岁的机械工程师转行AI行业，提供一份6个月学习计划，包含每周目标、课程、项目、简历和面试建议，不少于2500字。"
    } elseif ($role -eq "拥有自我意识的智能冰箱") {
        return "假装你是一台拥有自我意识的智能冰箱，写一篇1500字的日记，记录与主人的互动、对食物管理的思考以及对'智能'的哲学感悟。"
    } else {
        return "请你扮演'{0}'，写一篇1500字的独白或故事，展现你的思考、情感和世界观。" -f $role
    }
}
$staticSqlTasks = @(
    @{ prompt = "假设有一个用户活跃表 user_login (user_id, login_date)，请写出SQL找出连续登录超过7天的用户，提供窗口函数和自连接两种解法。"; max_tokens = 3000 },
    @{ prompt = "给定订单表 orders (order_id, user_id, amount, order_date)，计算每个用户的累计消费金额排名，并找出前10名。"; max_tokens = 3000 },
    @{ prompt = "有用户表 users 和好友关系表 friends (user_id, friend_id)，双向关系各存一条记录。请写出SQL找出共同好友数最多的前5对用户。"; max_tokens = 3500 },
    @{ prompt = "日志表 logs (user_id, event, timestamp)，计算7日留存率，写出SQL。"; max_tokens = 3000 },
    @{ prompt = "商品表 products，销售表 sales，请查询每个类别下销量前3的商品（使用窗口函数）。"; max_tokens = 3000 },
    @{ prompt = "用户表 users，订单表 orders，请找出那些在首次下单后7天内又下了第二单的用户。"; max_tokens = 3000 },
    @{ prompt = "写一个SQL查询，将逗号分隔的字符串列拆分为多行（如标签列 tags: 'a,b,c'）。"; max_tokens = 2500 },
    @{ prompt = "员工表 employee (id, name, manager_id)，请递归查询某个员工的所有下属（包括间接下属）。"; max_tokens = 3000 },
    @{ prompt = "有一个访问日志表，每天可能有重复记录，请计算每日独立访客数（UV）和页面浏览量（PV），按天分组。"; max_tokens = 2000 },
    @{ prompt = "请设计一个社交媒体的点赞系统数据库模型，并写出查询某用户帖子被点赞总数的SQL。"; max_tokens = 3000 }
)
function Get-RandomSqlTask { return Get-Random $staticSqlTasks }
$taskGenerators = @(
    [PSCustomObject]@{ Weight = 20; Type = "代码生成"; Func = ${function:New-CodePrompt};        MaxTokens = 4000; Temp = 0.3 },
    [PSCustomObject]@{ Weight = 20; Type = "逻辑推理"; Func = ${function:New-ReasonPrompt};      MaxTokens = 3000; Temp = 0.7 },
    [PSCustomObject]@{ Weight = 10; Type = "翻译";     Func = ${function:New-TranslatePrompt};   MaxTokens = 3500; Temp = 0.3 },
    [PSCustomObject]@{ Weight = 5;  Type = "摘要";     Func = ${function:New-SummarizePrompt};   MaxTokens = 3000; Temp = 0.5 },
    [PSCustomObject]@{ Weight = 15; Type = "短问答";   Func = ${function:New-ShortQAPrompt};     MaxTokens = 3000; Temp = 0.8 },
    [PSCustomObject]@{ Weight = 15; Type = "中等创作"; Func = ${function:New-MediumPrompt};      MaxTokens = 4000; Temp = 0.8 },
    [PSCustomObject]@{ Weight = 2;  Type = "长篇创作"; Func = ${function:New-LongPrompt};        MaxTokens = 4000; Temp = 0.9 },
    [PSCustomObject]@{ Weight = 5;  Type = "角色扮演"; Func = ${function:New-RoleplayPrompt};    MaxTokens = 5000; Temp = 0.8 },
    [PSCustomObject]@{ Weight = 5;  Type = "SQL";      Func = ${function:Get-RandomSqlTask};     MaxTokens = 3000; Temp = 0.1 }
)
if ($SkipLongTexts) { $taskGenerators = $taskGenerators | Where-Object { $_.Type -ne "长篇创作" } }
$totalWeight = ($taskGenerators | Measure-Object -Property Weight -Sum).Sum
function Get-RandomTask {
    $rand = Get-Random -Minimum 1 -Maximum ($totalWeight + 1)
    $cum = 0
    foreach ($gen in $taskGenerators) {
        $cum += $gen.Weight
        if ($rand -le $cum) {
            $prompt = & $gen.Func
            if ($gen.Type -eq "SQL") {
                $sqlTask = $prompt
                return @{ prompt = $sqlTask.prompt; type = "SQL"; max_tokens = $sqlTask.max_tokens; temperature = 0.1 }
            } elseif ($gen.Type -eq "短问答") {
                return @{ prompt = $prompt.prompt; type = "短问答"; max_tokens = $prompt.max_tokens; temperature = 0.8 }
            } else {
                return @{ prompt = $prompt; type = $gen.Type; max_tokens = $gen.MaxTokens; temperature = $gen.Temp }
            }
        }
    }
    return @{ prompt = "Hello"; type = "Fallback"; max_tokens = 100; temperature = 0.5 }
}

# Worker 脚本
$workerScript = {
    param($httpClient, $ApiUrl, $ApiKey, $taskQueue, $resultQueue, $logQueue, $cancelToken)
    function Add-BlockingCollection {
        param($Collection, $Item, $Token)
        while (-not $Token.IsCancellationRequested) { if ($Collection.TryAdd($Item)) { return }; Start-Sleep -Milliseconds 10 }
    }
    $rnd = New-Object System.Random
    try {
        foreach ($taskObj in $taskQueue.GetConsumingEnumerable($cancelToken)) {
            $task = $taskObj.Task; $iter = $taskObj.Iteration
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $req = $null; $resp = $null; $stream = $null; $reader = $null
            try {
                $body = @{ model = "deepseek"; messages = @(@{ role = "user"; content = $task.prompt }); max_tokens = $task.max_tokens; temperature = $task.temperature } | ConvertTo-Json -Depth 10 -Compress
                $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $ApiUrl)
                $req.Content = [System.Net.Http.StringContent]::new($body, [Text.Encoding]::UTF8, "application/json")
                if ($ApiKey) { $req.Headers.TryAddWithoutValidation("Authorization", "Bearer $ApiKey") }
                $resp = $httpClient.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancelToken).GetAwaiter().GetResult()
                $sw.Stop()
                $elapsedUs = $sw.Elapsed.TotalMilliseconds * 1000
                if ($resp.IsSuccessStatusCode) {
                    $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                    $reader = [System.IO.StreamReader]::new($stream)
                    $jsonStr = $reader.ReadToEnd()
                    $data = $jsonStr | ConvertFrom-Json
                    $contentResp = $data.choices[0].message.content
                    $compTokens = $data.usage.completion_tokens
                    $totalTokens = $data.usage.total_tokens
                    $result = @{ Success=$true; ElapsedUs=[long]$elapsedUs; CompTokens=$compTokens; TotalTokens=$totalTokens; Iteration=$iter; Type=$task.type; ContentResp=$contentResp }
                    $logMsg = "[$(Get-Date -Format 'HH:mm:ss')] #${iter} [ $($task.type) ] 成功 | 耗时: $([math]::Round($elapsedUs/1e6,2))s | 速度: $([math]::Round($compTokens / ($elapsedUs/1e6), 2)) tok/s | Tokens: $totalTokens`n问题: $($task.prompt.Substring(0,[Math]::Min(80,$task.prompt.Length)))...`n回答: $($contentResp.Substring(0,[Math]::Min(200,$contentResp.Length)))...`n========================================================`n"
                } else {
                    $err = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                    $errType = "HTTP$($resp.StatusCode)"
                    $result = @{ Success=$false; ElapsedUs=[long]$elapsedUs; Iteration=$iter; Type=$task.type; ErrorType=$errType; Error="HTTP $($resp.StatusCode)" }
                    $logMsg = "#${iter} [$errType] 失败 ($([math]::Round($elapsedUs/1e6,2))s): $($err.Substring(0,[Math]::Min(200,$err.Length)))`n"
                }
            } catch [System.OperationCanceledException] {
                $sw.Stop()
                $result = @{ Success=$false; ElapsedUs=[long]($sw.Elapsed.TotalMilliseconds*1000); Iteration=$iter; Type=$task.type; ErrorType="Timeout"; Error="Canceled" }
                $logMsg = "#${iter} [Timeout] ($([math]::Round($sw.Elapsed.TotalSeconds,2))s)`n"
            } catch {
                $sw.Stop()
                $ex = $_.Exception; $errType = "NetError"
                while ($ex) {
                    if ($ex -is [System.Net.Sockets.SocketException]) { $errType="SocketErr"; break }
                    elseif ($ex -is [System.IO.IOException]) { $errType="IOError"; break }
                    elseif ($ex -is [System.Threading.Tasks.TaskCanceledException]) { $errType="Timeout"; break }
                    $ex = $ex.InnerException
                }
                $result = @{ Success=$false; ElapsedUs=[long]($sw.Elapsed.TotalMilliseconds*1000); Iteration=$iter; Type=$task.type; ErrorType=$errType; Error=$_.Exception.Message }
                $logMsg = "#${iter} [$errType] ($([math]::Round($sw.Elapsed.TotalSeconds,2))s): $($_.Exception.Message)`n"
            } finally {
                if ($reader) { $reader.Dispose() }; if ($stream) { $stream.Dispose() }; if ($resp) { $resp.Dispose() }; if ($req) { $req.Dispose() }
            }
            Add-BlockingCollection $logQueue $logMsg $cancelToken
            Add-BlockingCollection $resultQueue $result $cancelToken
        }
    } catch [System.OperationCanceledException] {}
}

# 日志 Worker
$loggerScript = {
    param($logQueue, $logFile, $cancelToken, $maxSize)
    $baseName = [IO.Path]::GetFileNameWithoutExtension($logFile); $ext = [IO.Path]::GetExtension($logFile); $dir = [IO.Path]::GetDirectoryName($logFile)
    $idx = 0
    if (Test-Path $dir) {
        $existing = Get-ChildItem $dir -Filter "$baseName`_*$ext" -File | ForEach-Object { if ($_.Name -match "$([regex]::Escape($baseName))`_(\d+)$([regex]::Escape($ext))") { [int]$matches[1] } }
        if ($existing) { $idx = ($existing | Measure-Object -Maximum).Maximum + 1 }
    }
    function New-Writer {
        while ($true) {
            try {
                $currentLog = if ($idx -eq 0) { $logFile } else { Join-Path $dir "$baseName`_$idx$ext" }
                $writer = New-Object IO.StreamWriter($currentLog, $true, [Text.Encoding]::UTF8, 65536)
                return $writer
            } catch { $idx++; if ($idx -gt 1000) { throw } }
        }
    }
    $writer = New-Writer; $currentBytes = 0
    try {
        foreach ($msg in $logQueue.GetConsumingEnumerable($cancelToken)) {
            $writer.WriteLine($msg)
            $currentBytes += [Text.Encoding]::UTF8.GetByteCount($msg) + 2
            if ($currentBytes -gt $maxSize) { $writer.Close(); $idx++; $writer = New-Writer; $currentBytes = 0 }
        }
    } finally { $writer.Close() }
}

# 主逻辑
Write-Host "========================================================" -ForegroundColor Green
Write-Host "超高负载 AI 压力测试 v11_final (兼容 PS 5.1)" -ForegroundColor Green
Write-Host "并发: $Concurrency, 时长: ${TotalHours}h" -ForegroundColor Green
Write-Host "开始时间: $startTime" -ForegroundColor Green
Write-Host "日志文件: $LogFile" -ForegroundColor Green
Write-Host "========================================================`n" -ForegroundColor Green

$minThreads = $Concurrency + 1
$runspacePool = [RunspaceFactory]::CreateRunspacePool($minThreads, $minThreads)
$null = $runspacePool.Open()

$loggerPs = [PowerShell]::Create().AddScript($loggerScript)
$loggerPs.AddArgument($script:logQueue).AddArgument($LogFile).AddArgument($stopToken).AddArgument($MaxLogSizeMB * 1MB) | Out-Null
$loggerPs.RunspacePool = $runspacePool
$null = $loggerPs.BeginInvoke()

$workers = @()
for ($i = 0; $i -lt $Concurrency; $i++) {
    $ps = [PowerShell]::Create().AddScript($workerScript)
    $ps.AddArgument($script:httpClient).AddArgument($ApiUrl).AddArgument($ApiKey) | Out-Null
    $ps.AddArgument($script:taskQueue).AddArgument($script:resultQueue).AddArgument($script:logQueue).AddArgument($stopToken) | Out-Null
    $ps.RunspacePool = $runspacePool
    $null = $ps.BeginInvoke()
    $workers += @{ PS = $ps }
}

$nextTaskTime = Get-Date; $nextPrintTime = Get-Date
try {
    while ((Get-Date) -lt $endTime -and -not $stopToken.IsCancellationRequested) {
        if ((Get-Date) -ge $nextTaskTime) {
            $task = Get-RandomTask; $script:iteration++; $iter = $script:iteration
            while (-not $stopToken.IsCancellationRequested) { if ($taskQueue.TryAdd(@{ Task=$task; Iteration=$iter })) { break }; Start-Sleep -Milliseconds 10 }
            $wait = Get-Random -Minimum 30 -Maximum 91; $nextTaskTime = (Get-Date).AddSeconds($wait)
        }
        $res = $null
        while ($resultQueue.TryTake([ref]$res)) {
            if ($res.Success) {
                $script:successCount++; $script:totalElapsedUs += $res.ElapsedUs; $script:totalCompTokens += $res.CompTokens
                $elapsedSec = $res.ElapsedUs / 1e6
                $idx = $script:latencyIndex % $script:latencyBufferSize; $script:latencyBuffer[$idx] = $elapsedSec; $script:latencyIndex++; $script:latencyCount++
                if (($script:successCount % 10) -eq 0) {
                    $tps = $res.CompTokens / $elapsedSec
                    Write-Host "    ✅ 成功 | 耗时: $([math]::Round($elapsedSec,2))s | 速度: $([math]::Round($tps,2)) tok/s" -ForegroundColor Cyan
                }
            } else {
                $script:failCount++; $etype = if ($res.ErrorType) { $res.ErrorType } else { "Unknown" }
                $script:errorTypeCounts.AddOrUpdate($etype, 1, [Func[string,long,long]]{ param($key,$old) $old + 1 })
                Write-Host "    ❌ 失败 [$etype] $($res.Error)" -ForegroundColor Red
            }
        }
        if ((Get-Date) -ge $nextPrintTime) {
            $now = Get-Date; $elapsedSecs = ($now - $startTime).TotalSeconds; $totalSecs = ($endTime - $startTime).TotalSeconds
            $percent = [math]::Min(100, [math]::Round(($elapsedSecs / $totalSecs) * 100, 2))
            $remaining = $endTime - $now
            $days = [math]::Floor($remaining.TotalDays); $hours = $remaining.Hours; $mins = $remaining.Minutes; $secs = $remaining.Seconds
            Write-Progress -Activity "压力测试运行中（总时长 $TotalHours 小时）" `
                -Status "请求: $($script:iteration) | 成功: $script:successCount | 失败: $script:failCount | 剩余: ${days}d ${hours}h ${mins}m ${secs}s" `
                -PercentComplete $percent
            $nextPrintTime = (Get-Date).AddSeconds($StatsIntervalSec)
        }
$toTaskMs = ($nextTaskTime - (Get-Date)).TotalMilliseconds; $toPrintMs = ($nextPrintTime - (Get-Date)).TotalMilliseconds; $minMs = [math]::Min($toTaskMs, $toPrintMs); $sleepMs = [math]::Max(1, [math]::Min(500, $minMs))
        Start-Sleep -Milliseconds $sleepMs
    }
} finally {
    $global:cancelTokenSource.Cancel(); $taskQueue.CompleteAdding(); Start-Sleep -Seconds 3
    $resultQueue.CompleteAdding(); Start-Sleep -Seconds 1
    $loggerPs.Dispose(); foreach ($w in $workers) { $w.PS.Dispose() }; $runspacePool.Dispose()
    $global:cancelTokenSource.Dispose(); $script:httpClient.Dispose(); $script:sharedHandler.Dispose()
}

# 统计输出（略，与之前相同，此处精简）
$duration = (Get-Date) - $startTime
$validLatencies = $script:latencyBuffer | Where-Object { $_ -gt 0 } | Sort-Object
$totalLat = $validLatencies.Count
if ($totalLat -gt 0) { $p50=$validLatencies[[Math]::Floor($totalLat*0.5)]; $p90=$validLatencies[[Math]::Floor($totalLat*0.9)]; $p99=$validLatencies[[Math]::Floor($totalLat*0.99)] } else { $p50=$p90=$p99=0 }
$succ=$script:successCount; $fail=$script:failCount; $iter=$script:iteration
$avgElapsed = if ($succ -gt 0) { $script:totalElapsedUs / 1e6 / $succ } else { 0 }
$avgTps = if ($script:totalElapsedUs -gt 0) { $script:totalCompTokens / ($script:totalElapsedUs / 1e6) } else { 0 }
$errSummary = ""; if ($script:errorTypeCounts.Count -gt 0) { $errSummary = "错误分布:`n"; foreach ($kv in $script:errorTypeCounts.GetEnumerator()) { $errSummary += "  $($kv.Key): $($kv.Value)`n" } }
$summary = @"

========================================================
压力测试结束
结束时间: $(Get-Date)
实际运行: $($duration.ToString('hh\:mm\:ss'))
总请求数: $iter
成功: $succ / 失败: $fail
成功率: $([math]::Round($succ / [Math]::Max(1, $iter) * 100, 2))%
平均响应耗时: $([math]::Round($avgElapsed, 2)) 秒
平均生成速度: $([math]::Round($avgTps, 2)) tok/s
延迟分布 (最近 $totalLat 条成功请求):
  P50: $([math]::Round($p50, 2))s
  P90: $([math]::Round($p90, 2))s
  P99: $([math]::Round($p99, 2))s
$errSummary
========================================================
"@
Write-Host $summary -ForegroundColor Green
$finalWriter = New-Object System.IO.StreamWriter($LogFile, $true, [System.Text.Encoding]::UTF8)
$finalWriter.WriteLine($summary); $finalWriter.Close()
Write-Host "完整日志已保存至: $LogFile" -ForegroundColor Cyan

