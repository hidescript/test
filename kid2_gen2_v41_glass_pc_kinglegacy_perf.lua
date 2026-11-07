if _G.HzPerfDebug == nil then _G.HzPerfDebug = false end
do
  local t0 = os.clock()
  local last, step = t0, 0
  _G.HzPerf = function(label)
    local now = os.clock()
    step = step + 1
    local dbg = _G.HzPerfDebug == true
    if not dbg then pcall(function() dbg = getgenv().HzPerfDebug == true end) end
    if dbg then
      local msg = string.format("[PERF] Step %d: %dms (+%dms) - %s", step,
        math.floor((now - t0) * 1000 + 0.5), math.floor((now - last) * 1000 + 0.5), tostring(label))
      pcall(function()
        if _G.aa3542001e064bc52 then _G.aa3542001e064bc52(msg, "INFO") else print(msg) end
      end)
    end
    last = now
  end
end
_G.HzPerf("Bắt đầu execute")

-- [V35] C2: hằng số tập trung (đọc có fallback ở từng chỗ dùng)
_G.HzConst = {
  vault = { maxScripts = 100, staleCheck = 6 * 3600 },
  autoload = { maxPins = 20 },
  scriptblox = { pageMax = 20, cacheTTL = 300, cacheLimit = 40 },
  log = { maxBuffer = 500, maxRows = 80, flushDelay = 0.15 },
  rejoin = { maxRetries = 3, stableSeconds = 300 },
  antiafk = { minDelay = 60, maxDelay = 120 },
  adminCache = { ttl = 24 * 3600, fetchTimeout = 5 },
  lib = { gen2RefreshAfter = 3 * 86400 },
}

-- [PERF] ===== Phân loại máy tự động: _G.HzDetectPerfLevel() -> "high" | "med" | "low" =====
-- Ép tay: getgenv().HzPerfLevel = "low" | "med" | "high" | "auto" (mặc định auto).
-- Tương thích cũ: getgenv().HzLiteLoading = true → low, false → high (chỉ khi HzPerfLevel là auto).
-- Kết quả cache ở getgenv().HzPerfLevelCache (xoá biến này để đo lại). _G.HzLiteLoad = (level == "low").
do
  local function norm(v)
    if type(v) ~= "string" then return nil end
    v = v:lower()
    if v == "low" or v == "med" or v == "high" then return v end
    return nil
  end
  local function measure()
    local uis = game:GetService("UserInputService")
    -- 1) Máy cảm ứng không bàn phím → LOW
    local okT, touchOnly = pcall(function() return uis.TouchEnabled and not uis.KeyboardEnabled end)
    if okT and touchOnly then return "low" end
    -- 2) Đồ hoạ đang để thấp (Level01..Level03; Automatic = 0 thì bỏ qua)
    local okQ, q = pcall(function() return settings().Rendering.QualityLevel.Value end)
    if okQ and type(q) == "number" and q > 0 and q <= 3 then return "low" end
    -- 3) Đo FPS 8–16 khung Heartbeat (bỏ 2 khung đầu vì hay giật lúc khởi động), tối đa ~0.8s
    local level = "high"
    pcall(function()
      local RS = game:GetService("RunService")
      local t0 = os.clock()
      local last, frames, sum = t0, 0, 0
      while frames < 16 and (os.clock() - t0) < 0.8 do
        RS.Heartbeat:Wait()
        local now = os.clock()
        frames = frames + 1
        if frames > 2 then sum = sum + (now - last) end
        last = now
      end
      local n = frames - 2
      if n >= 3 and sum > 0 then
        local fps = n / sum
        if fps < 30 then level = "low" elseif fps < 50 then level = "med" end
      end
    end)
    -- 4) Ping > 250ms → ít nhất MED
    pcall(function()
      local lp = game:GetService("Players").LocalPlayer
      local ms = lp and lp:GetNetworkPing() * 1000
      if type(ms) == "number" and ms > 250 and level == "high" then level = "med" end
    end)
    return level
  end
  _G.HzDetectPerfLevel = function()
    local g = (type(getgenv) == "function" and getgenv()) or _G
    local forced = norm(g.HzPerfLevel)
    if not forced and (g.HzPerfLevel == nil or norm(g.HzPerfLevel) == nil) then
      local old = g.HzLiteLoading
      if old == true then forced = "low" elseif old == false then forced = "high" end
    end
    local level = forced
    if not level then
      level = norm(g.HzPerfLevelCache)
      if not level then
        level = measure()
        g.HzPerfLevelCache = level
      end
    end
    _G.HzPerfLvl = level
    _G.HzLiteLoad = (level == "low")
    if _G.HzPerfLogged ~= level then
      _G.HzPerfLogged = level
      local function lg()
        if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Perf level: " .. level, "INFO") return true end
      end
      if not lg() then task.delay(3, lg) end
    end
    return level
  end
  -- Chọn giá trị theo mức máy: _G.HzPerfPick(high, med, low)
  _G.HzPerfPick = function(h, m, l)
    local lv = _G.HzPerfLvl
    if not lv then
      local okP, r = pcall(_G.HzDetectPerfLevel)
      lv = okP and r or "high"
    end
    if lv == "low" then return l elseif lv == "med" then return m end
    return h
  end
  pcall(_G.HzDetectPerfLevel)
end

-- [V35] A1: dựng nội dung tab khi vào lần đầu
_G.HzLazyBuilt = _G.HzLazyBuilt or setmetatable({}, { __mode = "k" })
_G.HzLazyTab = function(tabRef, name, builderFn, forceNow)
  if type(builderFn) ~= "function" then return false end
  local builtTabs = _G.HzLazyBuilt
  local key = tabRef or builderFn
  if builtTabs[key] then return true end
  local function build()
    if builtTabs[key] then return end
    builtTabs[key] = true
    local ok, err = pcall(builderFn)
    if not ok then
      local msg = "Lazy tab '" .. tostring(name) .. "' lỗi: " .. tostring(err)
      if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, msg, "ERROR") else warn(msg) end
    end
  end
  if forceNow then build() return true end
  local ev
  pcall(function() ev = tabRef and tabRef.Raw and tabRef.Raw.OnEnter end)
  if typeof(ev) == "RBXScriptSignal" or (type(ev) == "table" and type(ev.Connect) == "function") then
    local conn
    local okC = pcall(function()
      conn = ev:Connect(function()
        build()
        if conn then pcall(function() conn:Disconnect() end) end
      end)
    end)
    if okC then return false end
  end
  build() -- [V35] fallback: Gen2 không có OnEnter → dựng ngay như cũ
  return true
end

-- Có cache -> đọc file (nhanh hơn HttpGet nhiều lần), cache > 3 ngày thì làm mới nền cho lần sau.
-- Không có writefile/readfile -> tự động quay về HttpGet như cũ.
do
  local FILE, STAMP, URL = "x8k2/rayfield_gen2.lua", "x8k2/rayfield_gen2.ts", "https://sirius.menu/gen2"
  local SUM = "x8k2/rayfield_gen2.sum"
  local REFRESH_AFTER = (((_G.HzConst or {}).lib or {}).gen2RefreshAfter) or (3 * 86400) -- [V35]
  local hasFS = type(isfile) == "function" and type(readfile) == "function" and type(writefile) == "function"
  local st = { src = nil, cached = false, busy = false }
  _G.HzGen2 = st

  local function sumOf(s, algo)
    if algo == "sha256" then
      local ok, h = pcall(function() return crypt.hash(s, "sha256") end)
      if ok and h then return "sha256:" .. tostring(h):lower() end
      return nil
    end
    local a, b = 1, 0
    for i = 1, #s, 4096 do
      local chunk = { string.byte(s, i, math.min(i + 4095, #s)) }
      for j = 1, #chunk do
        a = (a + chunk[j]) % 65521
        b = (b + a) % 65521
      end
    end
    return string.format("adler32:%08x:%d", b * 65536 + a, #s)
  end
  -- kiểm tra thô: là chuỗi, độ dài hợp lý, không phải bytecode nhị phân
  local function sane(s)
    if type(s) ~= "string" or #s < 2000 or #s > 8 * 1024 * 1024 then return false end
    local c = s:byte(1)
    if c and c < 32 and c ~= 9 and c ~= 10 and c ~= 13 then return false end
    return true
  end
  -- ghim hash (tuỳ chọn): _G.HzGen2Pin = "sha256:..." hoặc "adler32:..."
  local function matchesPin(s)
    local pin = _G.HzGen2Pin
    if type(pin) ~= "string" or pin == "" then return true end
    local algo = pin:match("^(%w+):")
    local got = algo and sumOf(s, algo)
    return got ~= nil and got:lower() == pin:lower()
  end
  local function warn(msg)
    if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, msg, "WARN") end
  end

  local function fetch()
    local ok, res = pcall(function() return game:HttpGet(URL) end)
    if not ok or not sane(res) then return nil end
    if not matchesPin(res) then
      warn("Rayfield Gen2 tải về KHÔNG khớp hash đã ghim.")
      if _G.HzGen2PinStrict == true then return nil end
    end
    return res
  end
  local function save(s)
    if not hasFS or not sane(s) then return end
    pcall(function()
      if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("x8k2") then makefolder("x8k2") end
      writefile(FILE, s)
      writefile(SUM, sumOf(s, "adler32"))
      writefile(STAMP, tostring(os.time()))
    end)
  end
  local function readCache()
    if not hasFS then return nil end
    local s
    pcall(function()
      if isfile(FILE) and isfile(SUM) then -- thiếu file checksum (cache cũ V27/V28) -> bỏ, tải lại 1 lần
        local d = readfile(FILE)
        if sane(d) and readfile(SUM) == sumOf(d, "adler32") and matchesPin(d) then s = d end
      end
    end)
    if not s and isfile and isfile(FILE) then warn("Cache Rayfield không hợp lệ (thiếu/sai checksum) - sẽ tải lại.") end
    return s
  end
  local function cacheAge()
    local age = math.huge
    pcall(function()
      if isfile(STAMP) then age = os.time() - (tonumber(readfile(STAMP)) or 0) end
    end)
    return age
  end

  _G.HzPreloadGen2 = function()
    if st.src or st.busy then return end
    st.busy = true
    pcall(function()
      local s = readCache()
      if s then
        st.src, st.cached = s, true
        if cacheAge() > REFRESH_AFTER then
          task.delay(10, function()
            local f = fetch()
            if f then save(f) end
          end)
        end
      else
        local f = fetch()
        if f then st.src, st.cached = f, false; save(f) end
      end
    end)
    st.busy = false
  end

  -- forceFresh = true: bỏ qua cache, tải mới (dùng khi cache hỏng)
  _G.HzGetGen2Src = function(forceFresh)
    if forceFresh then
      local f = fetch()
      if f then st.src, st.cached = f, false; save(f) end
      return f
    end
    local t0 = os.clock()
    while st.busy and os.clock() - t0 < 15 do task.wait(0.03) end
    if not st.src then _G.HzPreloadGen2() end
    return st.src
  end

  task.spawn(_G.HzPreloadGen2)
end

-- Lưu ý: Roblox KHÔNG có UIBlur cho từng Frame. Helper dựng hiệu ứng kính bằng độ trong suốt + viền sáng (UIStroke+UIGradient)
-- + lớp phản chiếu (Gloss). Tuỳ chọn blur = BlurEffect trong Lighting (làm mờ THẾ GIỚI 3D phía sau UI, không làm mờ UI khác),
-- chỉ nên dùng cho thẻ loading (ngắn). Không hỗ trợ/ lỗi -> tự bỏ qua, vẫn còn hiệu ứng kính.
-- Tắt toàn bộ: _G.HzGlassUI = false  |  Tắt riêng blur: _G.HzGlassBlur = false  |  LITE tự bỏ blur/gloss/gradient.
do
  local TweenService = game:GetService("TweenService")
  local Lighting = game:GetService("Lighting")
  local blurRefs, blurObj = 0, nil
  local blurGen = 0 -- [PERF] token: huỷ lệnh Destroy đang chờ nếu có người acquire lại giữa chừng

  local function blurAcquire(size)
    -- [PERF] chỉ HIGH mới có BlurEffect; MED/LOW không bao giờ tạo
    if _G.HzPerfLvl ~= "high" or _G.HzLiteLoad == true or _G.HzGlassBlur == false then return false end
    local ok = pcall(function()
      blurGen = blurGen + 1
      if not (blurObj and blurObj.Parent) then
        -- [PERF] tối đa 1 instance: dọn BlurEffect cùng tên còn sót trước khi tạo
        local nm = _G.HzBlurName or "HzGlassBlur"
        for _, e in ipairs(Lighting:GetChildren()) do
          if e:IsA("BlurEffect") and e.Name == nm then pcall(function() e:Destroy() end) end
        end
        local b = Instance.new("BlurEffect")
        b.Name = nm
        b.Size = 0
        b.Parent = Lighting
        blurObj = b
      end
      TweenService:Create(blurObj, TweenInfo.new(0.35), { Size = size or 10 }):Play()
    end)
    if ok then blurRefs = blurRefs + 1 end
    return ok
  end

  local function blurRelease()
    blurRefs = math.max(0, blurRefs - 1)
    if blurRefs > 0 or not blurObj then return end
    local b, gen = blurObj, blurGen
    -- [PERF] blurObj chỉ về nil khi thật sự Destroy → acquire giữa lúc fade-out sẽ dùng lại, không tạo cái thứ 2
    local function kill()
      if gen ~= blurGen or blurRefs > 0 then return end
      if blurObj == b then blurObj = nil end
      pcall(function() b:Destroy() end)
    end
    pcall(function()
      local tw = TweenService:Create(b, TweenInfo.new(0.3), { Size = 0 })
      tw.Completed:Connect(kill)
      tw:Play()
    end)
    task.delay(1, kill)
  end

  -- opts: radius, tint, transparency, stroke(false = không đụng viền), keepStrokeColor, strokeThickness,
  --       gloss(false), glossZ, blur(true), blurSize, blurTime
  _G.HzLiquidGlass = function(frame, opts)
    if typeof(frame) ~= "Instance" or _G.HzGlassUI == false then return nil end
    opts = opts or {}
    -- [PERF] HIGH: blur + gloss + stroke gradient | MED: gloss nhẹ + stroke phẳng | LOW: chỉ UICorner + UIStroke phẳng
    local lvl = _G.HzPerfLvl or (_G.HzLiteLoad == true and "low" or "high")
    local lite = (lvl == "low")
    local handle = {}
    pcall(function()
      if opts.tint then frame.BackgroundColor3 = opts.tint end
      if opts.transparency then frame.BackgroundTransparency = opts.transparency end
      frame.BorderSizePixel = 0

      if opts.radius then
        local c = frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, opts.radius)
        c.Parent = frame
      end

      if opts.stroke ~= false then
        local st = frame:FindFirstChildOfClass("UIStroke")
        if not st then st = Instance.new("UIStroke"); st.Parent = frame end
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        if not opts.keepStrokeColor then st.Color = Color3.fromRGB(255, 255, 255) end
        st.Thickness = opts.strokeThickness or 1.2
        st.Transparency = 0.45
        if lvl == "high" then -- [PERF] gradient chỉ ở HIGH; viền sáng "specular": đậm ở 2 góc chéo, nhạt ở giữa
          local g = Instance.new("UIGradient")
          g.Rotation = 45
          g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.35, 0.75),
            NumberSequenceKeypoint.new(0.65, 0.75),
            NumberSequenceKeypoint.new(1, 0.1),
          })
          g.Parent = st
        end
      end

      if opts.gloss ~= false and not lite then -- vệt phản chiếu ở nửa trên
        local gloss = Instance.new("Frame")
        gloss.Name = "Gloss"
        gloss.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        gloss.BorderSizePixel = 0
        gloss.Active = false
        gloss.ZIndex = opts.glossZ or 0
        gloss.Size = UDim2.new(1, 0, 0.55, 0)
        local gc = frame:FindFirstChildOfClass("UICorner")
        local gcr = Instance.new("UICorner")
        gcr.CornerRadius = gc and gc.CornerRadius or UDim.new(0, opts.radius or 14)
        gcr.Parent = gloss
        local gg = Instance.new("UIGradient")
        gg.Rotation = 90
        gg.Transparency = NumberSequence.new({
          NumberSequenceKeypoint.new(0, (lvl == "med") and 0.93 or 0.86), -- [PERF] MED: gloss nhạt hơn
          NumberSequenceKeypoint.new(1, 1),
        })
        gg.Parent = gloss
        gloss.Parent = frame
      end

      if opts.blur and blurAcquire(opts.blurSize) then
        local released = false
        local function rel()
          if released then return end
          released = true
          blurRelease()
        end
        frame.AncestryChanged:Connect(function()
          if not frame:IsDescendantOf(game) then rel() end
        end)
        task.delay(opts.blurTime or 15, rel) -- chốt an toàn: tự nhả blur sau N giây
        handle.ReleaseBlur = rel
      end
    end)
    return handle
  end
end

do
  local HttpService = game:GetService("HttpService")
  local Players = game:GetService("Players")
  local LocalizationService = game:GetService("LocalizationService")
  local CFG_DIR, CFG_FILE = "x8k2", "x8k2/language.json"

  local TR = {
    ["Nguồn: ScriptBlox.com"] = {"Source: ScriptBlox.com","Fonte: ScriptBlox.com"},
    ["ℹ️ Script do cộng đồng ScriptBlox đăng tải, không phải của HiulzHub. Hãy cân nhắc trước khi chạy — script chỉ chạy khi bạn bấm ▶ Chạy."] = {"ℹ️ Scripts are posted by the ScriptBlox community, not by HiulzHub. Think before running — a script only runs when you press ▶ Run.","ℹ️ Os scripts são publicados pela comunidade ScriptBlox, não pelo HiulzHub. Pense antes de executar — um script só roda quando você toca em ▶ Executar."},
    ["Tìm kiếm"] = {"Search","Pesquisar"},
    ["Tìm script trên ScriptBlox..."] = {"Search scripts on ScriptBlox...","Pesquisar scripts no ScriptBlox..."},
    ["🔍 Tìm"] = {"🔍 Search","🔍 Pesquisar"},
    ["🔄 Tải lại"] = {"🔄 Reload","🔄 Recarregar"},
    ["Bộ lọc"] = {"Filters","Filtros"},
    ["Chỉ script đã xác minh (Verified)"] = {"Verified scripts only","Apenas scripts verificados"},
    ["Chỉ script không cần key"] = {"Keyless scripts only","Apenas scripts sem key"},
    ["Chỉ script đa năng (Universal)"] = {"Universal scripts only","Apenas scripts universais"},
    ["Danh sách script"] = {"Script list","Lista de scripts"},
    ["Tiến trình tải ScriptBlox"] = {"ScriptBlox load progress","Progresso de carga do ScriptBlox"},
    ["Bấm 🔄 Tải lại để tải danh sách script mới nhất."] = {"Press 🔄 Reload to load the latest scripts.","Toque em 🔄 Recarregar para carregar os scripts mais recentes."},
    ["— Chưa có dữ liệu —"] = {"— No data yet —","— Sem dados ainda —"},
    ["⬅ Trang trước"] = {"⬅ Previous page","⬅ Página anterior"},
    ["Trang sau ➡"] = {"Next page ➡","Próxima página ➡"},
    ["Chọn một script ở trên để xem chi tiết."] = {"Pick a script above to see its details.","Escolha um script acima para ver os detalhes."},
    ["📋 Copy Loadstring"] = {"📋 Copy loadstring","📋 Copiar loadstring"},
    ["Chú thích: ✅ đã xác minh · 🔑 cần key · 🎮 game · 👁 lượt xem"] = {"Legend: ✅ verified · 🔑 needs key · 🎮 game · 👁 views","Legenda: ✅ verificado · 🔑 precisa de key · 🎮 jogo · 👁 visualizações"},
    ["⏳ Đang tải từ ScriptBlox..."] = {"⏳ Loading from ScriptBlox...","⏳ Carregando do ScriptBlox..."},
    ["Đang tải từ ScriptBlox..."] = {"Loading from ScriptBlox...","Carregando do ScriptBlox..."},
    ["❌ Lỗi tải"] = {"❌ Load error","❌ Erro ao carregar"},
    ["Đã tải %d script (trang %d/%d)"] = {"Loaded %d scripts (page %d/%d)","%d scripts carregados (página %d/%d)"},
    ["📄 Trang %d/%d • %d script"] = {"📄 Page %d/%d • %d scripts","📄 Página %d/%d • %d scripts"},
    ["Không có script nào phù hợp."] = {"No matching scripts.","Nenhum script correspondente."},
    ["Không tải được dữ liệu từ ScriptBlox: "] = {"Could not load data from ScriptBlox: ","Não foi possível carregar dados do ScriptBlox: "},
    ["Đang ở trang đầu."] = {"Already on the first page.","Já está na primeira página."},
    ["Đang ở trang cuối."] = {"Already on the last page.","Já está na última página."},
    ["Tiêu đề: "] = {"Title: ","Título: "},
    ["Lượt xem: "] = {"Views: ","Visualizações: "},
    ["Lượt chạy: "] = {"Executions: ","Execuções: "},
    ["Loại: "] = {"Type: ","Tipo: "},
    ["Ngày tạo: "] = {"Created: ","Criado em: "},
    ["Script này có thể đã bị Patched."] = {"This script may be patched.","Este script pode estar patcheado."},
    ["Không chạy trên: "] = {"Does not run on: ","Não roda em: "},
    ["Link lấy key: "] = {"Key link: ","Link da key: "},
    ["❌ Slug không hợp lệ!"] = {"❌ Invalid slug!","❌ Slug inválido!"},
    ["⚠️ Script này cần KEY! Bấm ▶ Chạy lần nữa để xác nhận."] = {"⚠️ This script needs a KEY! Press ▶ Run again to confirm.","⚠️ Este script precisa de KEY! Toque em ▶ Executar de novo para confirmar."},
    ["⚠️ Script này có thể đã bị Patched! Bấm ▶ Chạy lần nữa để xác nhận."] = {"⚠️ This script may be patched! Press ▶ Run again to confirm.","⚠️ Este script pode estar patcheado! Toque em ▶ Executar de novo para confirmar."},
    ["Đang tải script..."] = {"Loading script...","Carregando script..."},
    ["❌ Không tải được mã script: "] = {"❌ Could not download the script code: ","❌ Não foi possível baixar o código do script: "},
    ["✅ Đã chạy: "] = {"✅ Ran: ","✅ Executado: "},
    ["⭐ Ghim"] = {"⭐ Pin","⭐ Fixar"},
    ["💾 Lưu vào Kho"] = {"💾 Save to vault","💾 Salvar no cofre"},
    ["⭐ Đã ghim: "] = {"⭐ Pinned: ","⭐ Fixado: "},
    ["☆ Đã bỏ ghim: "] = {"☆ Unpinned: ","☆ Desafixado: "},
    [" — sẽ tự chạy khi khởi động"] = {" — will auto-run on startup"," — vai rodar sozinho ao iniciar"},
    ["Danh sách ghim đã đầy (tối đa 20)."] = {"The pin list is full (max 20).","A lista de fixados está cheia (máx. 20)."},
    ["Link không hợp lệ."] = {"Invalid link.","Link inválido."},
    ["⭐ Đã ghim — tự chạy khi khởi động"] = {"⭐ Pinned — auto-runs on startup","⭐ Fixado — roda sozinho ao iniciar"},
    ["Đã ghim — tự chạy khi khởi động"] = {"Pinned — auto-runs on startup","Fixado — roda sozinho ao iniciar"},
    ["💾 Đã lưu vào Kho: "] = {"💾 Saved to vault: ","💾 Salvo no cofre: "},
    ["❌ Kho script chưa sẵn sàng."] = {"❌ The script vault is not ready yet.","❌ O cofre de scripts ainda não está pronto."},
    ["⭐ Đang tự chạy %d script đã ghim..."] = {"⭐ Auto-running %d pinned script(s)...","⭐ Executando %d script(s) fixado(s)..."},
    ["Phím tắt"] = {"Shortcuts","Atalhos"},
    ["⌨️ Phím tắt"] = {"⌨️ Shortcuts","⌨️ Atalhos"},
    ["👁 Ẩn/hiện menu"] = {"👁 Show/hide menu","👁 Mostrar/ocultar menu"},
    ["Mặc định: RightShift"] = {"Default: RightShift","Padrão: RightShift"},
    ["🎵 Bật/tắt nhạc"] = {"🎵 Play/pause music","🎵 Pausar/retomar música"},
    ["Mặc định: M — chỉ có tác dụng khi đang có bài phát"] = {"Default: M — only works while a song is playing","Padrão: M — só funciona com uma música tocando"},
    ["Tự động chạy"] = {"Auto-run","Execução automática"},
    ["⭐ Tự động chạy (script đã ghim)"] = {"⭐ Auto-run (pinned scripts)","⭐ Execução automática (scripts fixados)"},
    ["⭐ Tự chạy script đã ghim khi khởi động"] = {"⭐ Auto-run pinned scripts on startup","⭐ Executar scripts fixados ao iniciar"},
    ["⭐ Chưa ghim script nào."] = {"⭐ No scripts pinned yet.","⭐ Nenhum script fixado ainda."},
    ["🧹 Bỏ ghim tất cả"] = {"🧹 Unpin all","🧹 Desafixar tudo"},
    ["Đã bỏ ghim tất cả."] = {"All scripts unpinned.","Todos os scripts desafixados."},
    ["🌐 Ngôn ngữ / Language"] = {"🌐 Language","🌐 Idioma"},
    ["Ngôn ngữ / Language"] = {"Language","Idioma"},
    ["Auto (theo quốc gia)"] = {"Auto (by country)", "Auto (por país)"}, -- [FIX LANG]
    ["🌍 Khu vực / Region: "] = {"🌍 Region: ","🌍 Região: "},
    ["Language / Ngôn ngữ"] = {"Language","Idioma"},
    ["Localization Gen2: BẬT (locale = %s) — đổi ngôn ngữ trực tiếp"] = {"Gen2 localization: ON (locale = %s) — live language switching","Localização Gen2: ATIVADA (locale = %s) — troca de idioma em tempo real"},
    ["Localization Gen2 không khả dụng — dùng dịch lúc dựng UI (chế độ cũ)."] = {"Gen2 localization unavailable — using build-time translation (legacy mode).","Localização Gen2 indisponível — usando tradução na montagem da UI (modo antigo)."},
    ["Đóng toàn bộ script?"] = {"Close the entire script?","Fechar o script inteiro?"},
    ["Tắt mọi chức năng, dừng nhạc, xoá HUD và gỡ menu. Bạn cần execute lại script để dùng tiếp."] = {"This turns off every feature, stops the music, removes the HUDs and unloads the menu. You will need to execute the script again to use it.","Isso desativa todos os recursos, para a música, remove os HUDs e descarrega o menu. Você precisará executar o script de novo para usá-lo."},
    ["Hủy"] = {"Cancel","Cancelar"},
    ["Đóng toàn bộ"] = {"Close all","Fechar tudo"},
    ["Bỏ ghim tất cả?"] = {"Unpin all?","Desafixar tudo?"},
    ["Xoá toàn bộ script khỏi danh sách Auto-run. Script trong Kho không bị xoá."] = {"Remove every script from the Auto-run list. Scripts in the Vault are kept.","Remove todos os scripts da lista de Auto-run. Os scripts do Cofre são mantidos."},
    ["Bỏ ghim"] = {"Unpin","Desafixar"},
    ["Xoá script?"] = {"Delete script?","Excluir script?"},
    ["Xoá"] = {"Delete","Excluir"},
    ["Quét sạch log?"] = {"Clear the log?","Limpar o log?"},
    ["Xoá toàn bộ nhật ký trong khung log."] = {"Delete all entries in the log box.","Exclui todas as entradas da caixa de log."},
    ["Quét sạch"] = {"Clear","Limpar"},
    ["▶ Chạy Auto-run ngay"] = {"▶ Run Auto-run now","▶ Executar Auto-run agora"},
    ["Chưa có script Auto-run nào."] = {"No Auto-run scripts yet.","Nenhum script em Auto-run ainda."},
    ["Auto-run đang tắt hoặc ở chế độ chỉ copy."] = {"Auto-run is off or in copy-only mode.","Auto-run desligado ou em modo somente copiar."},
    ["🆕 Có bản V%s — liên hệ Discord để lấy"] = {"🆕 Version V%s is out — contact us on Discord to get it","🆕 Versão V%s disponível — fale conosco no Discord para obter"},
    ["[THÀNH CÔNG]"] = {"[SUCCESS]","[SUCESSO]"},
    ["[CẢNH BÁO]"] = {"[WARNING]","[AVISO]"},
    ["[LỖI]"] = {"[ERROR]","[ERRO]"},
    ["📝 Nhật Ký"] = {"📝 Log","📝 Log"},
    ["📝 Nhật Ký  ✖%d ⚠%d ✔%d  [%s]"] = {"📝 Log  ✖%d ⚠%d ✔%d  [%s]","📝 Log  ✖%d ⚠%d ✔%d  [%s]"},
    ["Executor không hỗ trợ writefile"] = {"Executor does not support writefile","O executor não suporta writefile"},
    ["Đã dọn dẹp nhật ký hệ thống."] = {"System log cleared.","Log do sistema limpo."},
    ["Đã lưu nhật ký: "] = {"Log saved: ","Log salvo: "},
    ["Lưu nhật ký thất bại: "] = {"Failed to save log: ","Falha ao salvar o log: "},
    ["Đã copy nhật ký vào clipboard."] = {"Log copied to clipboard.","Log copiado para a área de transferência."},
    ["Executor không hỗ trợ copy."] = {"Executor does not support copy.","O executor não suporta cópia."},
    ["Đang phát: "] = {"Now playing: ","Tocando agora: "},
    ["bạn"] = {"there","você"},
    ["Xin chào, "] = {"Hello, ","Olá, "},
    ["Lỗi tải Rayfield Gen2: "] = {"Failed to load Rayfield Gen2: ","Falha ao carregar o Rayfield Gen2: "},
    ["Lỗi"] = {"Error","Erro"},
    ["Thư viện GUI (Rayfield Gen2) không tải được. Dừng script."] = {"Could not load the GUI library (Rayfield Gen2). Script stopped.","Não foi possível carregar a biblioteca de GUI (Rayfield Gen2). Script interrompido."},
    ["Tải thành công Rayfield Gen2"] = {"Rayfield Gen2 loaded successfully","Rayfield Gen2 carregado com sucesso"},
    ["Callback lỗi: "] = {"Callback error: ","Erro de callback: "},
    ["Menu đã tải xong — sẵn sàng sử dụng!"] = {"Menu loaded — ready to use!","Menu carregado — pronto para usar!"},
    ["❌ Đã hết lượt copy (Tối đa 3 lần)!"] = {"❌ Copy limit reached (max 3 times)!","❌ Limite de cópias atingido (máx. 3 vezes)!"},
    ["✅ Đã copy script vào clipboard!\n("] = {"✅ Script copied to clipboard!\n(","✅ Script copiado para a área de transferência!\n("},
    ["❌ Executor không hỗ trợ copy!"] = {"❌ Executor does not support copy!","❌ O executor não suporta cópia!"},
    ["❌ Script này đã bị xóa bởi tác giả!"] = {"❌ This script has been deleted by its author!","❌ Este script foi excluído pelo autor!"},
    ["Lỗi tải 404: "] = {"404 error: ","Erro 404: "},
    ["Quá trình tải thất bại... "] = {"Download failed... ","Falha no download... "},
    ["Lỗi thực thi: "] = {"Execution error: ","Erro de execução: "},
    ["Chặn Script Chết: "] = {"Dead script blocked: ","Script morto bloqueado: "},
    ["❌ Script bị lỗi cú pháp, không thể chạy!"] = {"❌ Script has a syntax error and cannot run!","❌ O script tem um erro de sintaxe e não pode ser executado!"},
    ["Lỗi Cú Pháp Script: "] = {"Script syntax error: ","Erro de sintaxe do script: "},
    ["✅ Quá trình tải thành công!"] = {"✅ Download successful!","✅ Download concluído com sucesso!"},
    ["Tải & Chạy thành công: "] = {"Downloaded & ran successfully: ","Baixado e executado com sucesso: "},
    ["Tối ưu (Auto)"] = {"Optimized (Auto)","Otimizado (Auto)"},
    ["Phát hiện: "] = {"Detected: ","Detectado: "},
    [".\nBật Low Mode để giảm tải."] = {".\nEnable Low Mode to reduce load.",".\nAtive o Low Mode para reduzir a carga."},
    ["Tự động kích hoạt Low Mode do: "] = {"Low Mode auto-enabled due to: ","Low Mode ativado automaticamente devido a: "},
    ["Copy script thông minh: "] = {"Smart script copy: ","Cópia inteligente de script: "},
    ["Đang load script..."] = {"Loading script...","Carregando script..."},
    ["Bỏ qua »"] = {"Skip »","Pular »"},
    ["Đang bỏ qua..."] = {"Skipping...","Pulando..."},
    ["Script (Smart) tải lỗi 404: "] = {"Script (Smart) 404 error: ","Script (Smart) erro 404: "},
    ["Load thất bại: "] = {"Load failed: ","Falha ao carregar: "},
    ["Script (Smart) Load thất bại: "] = {"Script (Smart) load failed: ","Script (Smart) falha ao carregar: "},
    ["Script (Smart) Chặn Script Chết: "] = {"Script (Smart) dead script blocked: ","Script (Smart) script morto bloqueado: "},
    ["Hoàn thành load script!"] = {"Script loaded!","Script carregado!"},
    ["Script (Smart) Hoàn thành: "] = {"Script (Smart) completed: ","Script (Smart) concluído: "},
    ["scripts.json sai định dạng JSON: "] = {"scripts.json has invalid JSON format: ","O scripts.json tem um formato JSON inválido: "},
    ["Không tải được scripts.json: "] = {"Could not load scripts.json: ","Não foi possível carregar o scripts.json: "},
    ["Đã tải DB script v%s (%d danh sách) từ %s"] = {"Loaded script DB v%s (%d lists) from %s","Banco de scripts v%s carregado (%d listas) de %s"},
    ["Không tải được DB script (GitHub + cache đều lỗi)."] = {"Could not load script DB (both GitHub and cache failed).","Não foi possível carregar o banco de scripts (GitHub e cache falharam)."},
    ["Thiếu danh sách script: "] = {"Missing script list: ","Lista de scripts ausente: "},
    ["⚠️ Không tải được danh sách script ["] = {"⚠️ Could not load script list [","⚠️ Não foi possível carregar a lista de scripts ["},
    ["]. Kiểm tra mạng/URL GitHub rồi execute lại."] = {"]. Check your network/GitHub URL and execute again.","]. Verifique sua rede/URL do GitHub e execute de novo."},
    ["Nhân Vật"] = {"Characters","Personagens"},
    ["Không khớp từ khoá tìm kiếm"] = {"No match for the search keyword","Nenhum resultado para a palavra-chave"},
    ["Cài đặt"] = {"Settings","Configurações"},
    ["Thành công"] = {"Success","Sucesso"},
    [" Đã sao chép Script Jump Showdown vào clipboard. Dán vào Executor (Ctrl+V)."] = {" Jump Showdown script copied to clipboard. Paste it into your Executor (Ctrl+V)."," Script do Jump Showdown copiado para a área de transferência. Cole no seu executor (Ctrl+V)."},
    ["Executor/ môi trường không hỗ trợ setclipboard. Link đã được hiển thị trong console."] = {"Executor/environment does not support setclipboard. The link was shown in the console.","O executor/ambiente não suporta setclipboard. O link foi mostrado no console."},
    ["Không Có"] = {"None","Nenhum"},
    ["Chọn bài hát..."] = {"Choose a song...","Escolha uma música..."},
    ["Nhập Sound ID thủ công"] = {"Enter Sound ID manually","Digitar Sound ID manualmente"},
    ["Ví dụ: 127521546166507"] = {"Example: 127521546166507","Exemplo: 127521546166507"},
    ["Không xác định"] = {"Unknown","Desconhecido"},
    ["Vui lòng đợi"] = {"Please wait","Aguarde"},
    ["Bạn vừa gửi rồi — thử lại sau %d giây."] = {"You just sent one — try again in %d seconds.","Você acabou de enviar um — tente de novo em %d segundos."},
    ["Thử lại sau %d giây."] = {"Try again in %d seconds.","Tente de novo em %d segundos."},
    ["\n\n[...đã cắt bớt...]"] = {"\n\n[...truncated...]","\n\n[...cortado...]"},
    ["Lỗi Webhook"] = {"Webhook error","Erro de webhook"},
    ["Không thể lấy Webhook thực từ server.\nVui lòng kiểm tra lại đường dẫn!"] = {"Could not get the real webhook from the server.\nPlease check the link!","Não foi possível obter o webhook real do servidor.\nConfira o link!"},
    ["Gửi thành công"] = {"Sent successfully","Enviado com sucesso"},
    ["Cảm ơn!\nNội dung đã được gửi tới Discord."] = {"Thank you!\nYour message was sent to Discord.","Obrigado!\nSua mensagem foi enviada ao Discord."},
    ["Nội dung đã gửi tới Discord."] = {"Your message was sent to Discord.","Sua mensagem foi enviada ao Discord."},
    ["Lỗi gửi"] = {"Send error","Erro de envio"},
    ["Không thể gửi. Executor có thể không hỗ trợ request."] = {"Could not send. Your executor may not support requests.","Não foi possível enviar. Seu executor pode não suportar requisições."},
    ["Script đã được load trước đó."] = {"Script was already loaded.","O script já tinha sido carregado."},
    ["Không tải được nội dung script từ URL."] = {"Could not fetch the script content from the URL.","Não foi possível obter o conteúdo do script pela URL."},
    ["loadstring lỗi: "] = {"loadstring error: ","erro de loadstring: "},
    ["Fix Lag Turbo - Lỗi"] = {"Fix Lag Turbo - Error","Fix Lag Turbo - Erro"},
    ["Đã dọn xong!\n Tắt bóng, xóa cỏ 3D & giảm chất lượng tối đa."] = {"Done!\n Shadows off, 3D grass removed & quality set to minimum.","Pronto!\n Sombras desligadas, grama 3D removida e qualidade no mínimo."},
    ["Tối ưu hóa - Lỗi"] = {"Optimization - Error","Otimização - Erro"},
    ["Khôi phục"] = {"Restore","Restaurar"},
    ["Chưa có cấu hình nào bị giảm để khôi phục."] = {"No reduced settings to restore.","Nenhuma configuração reduzida para restaurar."},
    ["Đang khôi phục (Sẽ mất vài giây)..."] = {"Restoring (takes a few seconds)...","Restaurando (leva alguns segundos)..."},
    ["Đã khôi phục toàn bộ cấu hình gốc thành công."] = {"All original settings restored successfully.","Todas as configurações originais foram restauradas com sucesso."},
    ["Khôi phục - Lỗi"] = {"Restore - Error","Restaurar - Erro"},
    ["Đã xóa toàn bộ tin nhắn rác trong khung chat!"] = {"All spam messages in the chat were cleared!","Todas as mensagens de spam do chat foram apagadas!"},
    ["Không tìm thấy dữ liệu chat!"] = {"Chat data not found!","Dados do chat não encontrados!"},
    ["Game sử dụng TextChatService mới hoặc Custom Chat!"] = {"This game uses the new TextChatService or a Custom Chat!","Este jogo usa o novo TextChatService ou um chat personalizado!"},
    ["Đã bật HUD FPS/PING | FPS hiện tại: "] = {"FPS/PING HUD enabled | Current FPS: ","HUD de FPS/PING ativado | FPS atual: "},
    ["Tìm server khác..."] = {"Finding another server...","Procurando outro servidor..."},
    ["Không tìm được server (cần mở HTTP hoặc thử lại)."] = {"Could not find a server (HTTP must be available, or try again).","Não foi possível encontrar um servidor (o HTTP precisa estar disponível, ou tente de novo)."},
    ["Tạm thời không có server trống, chọn ngẫu nhiên..."] = {"No empty servers right now, picking a random one...","Nenhum servidor vazio agora, escolhendo um aleatório..."},
    ["Không thể chọn server."] = {"Could not pick a server.","Não foi possível escolher um servidor."},
    ["Đang chuyển sang server: "] = {"Switching to server: ","Mudando para o servidor: "},
    ["Lỗi: LocalPlayer chưa sẵn sàng."] = {"Error: LocalPlayer is not ready.","Erro: o LocalPlayer não está pronto."},
    ["Tìm server ít người nhất..."] = {"Finding the least populated server...","Procurando o servidor com menos jogadores..."},
    ["Không tìm được server phù hợp."] = {"Could not find a suitable server.","Não foi possível encontrar um servidor adequado."},
    ["Đang join server %s (%d/%d)"] = {"Joining server %s (%d/%d)","Entrando no servidor %s (%d/%d)"},
    ["Không thể lấy JobId hiện tại."] = {"Could not get the current JobId.","Não foi possível obter o JobId atual."},
    ["Đang join lại server hiện tại: "] = {"Rejoining the current server: ","Reentrando no servidor atual: "},
    ["Không thể lấy JobID hiện tại."] = {"Could not get the current JobID.","Não foi possível obter o JobID atual."},
    ["Đã copy JobID vào clipboard."] = {"JobID copied to clipboard.","JobID copiado para a área de transferência."},
    ["Không thể copy (executor không hỗ trợ). JobID: "] = {"Cannot copy (executor unsupported). JobID: ","Não foi possível copiar (executor sem suporte). JobID: "},
    ["❌ Vui lòng nhập JobID trước!"] = {"❌ Please enter a JobID first!","❌ Digite um JobID primeiro!"},
    ["❌ JobID không hợp lệ! Vui lòng kiểm tra lại."] = {"❌ Invalid JobID! Please check it again.","❌ JobID inválido! Confira de novo."},
    ["⏳ Đang thử kết nối vào JobID: "] = {"⏳ Trying to connect to JobID: ","⏳ Tentando conectar ao JobID: "},
    ["❌ Lỗi: LocalPlayer chưa sẵn sàng."] = {"❌ Error: LocalPlayer is not ready.","❌ Erro: o LocalPlayer não está pronto."},
    ["❌ Lỗi: JobID này không tồn tại hoặc KHÔNG thuộc game này!"] = {"❌ Error: this JobID does not exist or does NOT belong to this game!","❌ Erro: este JobID não existe ou NÃO pertence a este jogo!"},
    ["⚠️ Cảnh báo: Nếu chưa được dịch chuyển, JobID có thể KHÔNG thuộc game này hoặc server đã đầy!"] = {"⚠️ Warning: If you were not teleported, the JobID may NOT belong to this game or the server is full!","⚠️ Aviso: se você não foi teleportado, o JobID pode NÃO pertencer a este jogo ou o servidor está cheio!"},
    ["📎 Code vào sever này! "] = {"📎 Code to join this server! ","📎 Código para entrar neste servidor! "},
    ["Đã copy teleport code (current) vào clipboard."] = {"Teleport code (current) copied to clipboard.","Código de teleporte (atual) copiado para a área de transferência."},
    ["Không thể copy (executor không hỗ trợ).\nTeleport code: "] = {"Cannot copy (executor unsupported).\nTeleport code: ","Não foi possível copiar (executor sem suporte).\nCódigo de teleporte: "},
    ["Thu thập danh sách server (có thể mất vài giây)..."] = {"Collecting the server list (may take a few seconds)...","Coletando a lista de servidores (pode levar alguns segundos)..."},
    ["Không lấy được server để copy."] = {"Could not get servers to copy.","Não foi possível obter servidores para copiar."},
    ["Không thể mã hoá JSON."] = {"Could not encode JSON.","Não foi possível codificar o JSON."},
    ["Đã copy danh sách server (JSON) vào clipboard."] = {"Server list (JSON) copied to clipboard.","Lista de servidores (JSON) copiada para a área de transferência."},
    ["Không thể copy (executor không hỗ trợ). Bắt đầu in JSON trong console..."] = {"Cannot copy (executor unsupported). Printing JSON to the console...","Não foi possível copiar (executor sem suporte). Imprimindo o JSON no console..."},
    ["Nhật Ký"] = {"Log","Log"},
    ["Nhật ký"] = {"Log","Log"},
    ["✅ Đã copy nhật ký vào clipboard!"] = {"✅ Log copied to clipboard!","✅ Log copiado para a área de transferência!"},
    ["❌ Executor không hỗ trợ copy."] = {"❌ Executor does not support copy.","❌ O executor não suporta cópia."},
    ["✅ Đã lưu: "] = {"✅ Saved: ","✅ Salvo: "},
    ["❌ Lỗi: "] = {"❌ Error: ","❌ Erro: "},
    ["Đã bật chế độ Anti-AFK"] = {"Anti-AFK mode enabled","Modo Anti-AFK ativado"},
    ["Đã tắt chế độ Anti-AFK"] = {"Anti-AFK mode disabled","Modo Anti-AFK desativado"},
    ["Đang tắt menu và dọn dẹp..."] = {"Closing the menu and cleaning up...","Fechando o menu e limpando..."},
    ["Đã đóng Menu và tắt tất cả chức năng!"] = {"Menu closed and all features disabled!","Menu fechado e todos os recursos desativados!"},
    ["Thông tin"] = {"Info","Info"},
    ["Thời gian chạy"] = {"Uptime","Tempo ativo"},
    ["Thông báo"] = {"Notification","Notificação"},
    ["⚠️ CẢNH BÁO: ADMIN/MOD ["] = {"⚠️ WARNING: ADMIN/MOD [","⚠️ AVISO: ADMIN/MOD ["},
    ["] VỪA VÀO SERVER! ⚠️"] = {"] JUST JOINED THE SERVER! ⚠️","] ENTROU NO SERVIDOR! ⚠️"},
    ["Khác"] = {"Other","Outros"},
    ["Kiểm tra chỉ tải về và biên dịch thử, KHÔNG chạy script."] = {"Checking only downloads and test-compiles the script; it does NOT run it.","A verificação só baixa e compila o script para teste; NÃO o executa."},
    ["Link script (https://...)"] = {"Script link (https://...)","Link do script (https://...)"},
    ["📋 Copy link script"] = {"📋 Copy script link","📋 Copiar link do script"},
    ["Vui lòng nhập link script trước!"] = {"Please enter a script link first!","Digite o link do script primeiro!"},
    ["Link phải bắt đầu bằng https://"] = {"The link must start with https://","O link deve começar com https://"},
    ["Đang kiểm tra script..."] = {"Checking script...","Verificando script..."},
    ["Đã lưu: "] = {"Saved: ","Salvo: "},
    ["Script đã tồn tại trong danh sách."] = {"This script is already in your list.","Este script já está na sua lista."},
    ["Danh sách đã đầy (tối đa 100)."] = {"The list is full (max 100).","A lista está cheia (máx. 100)."},
    ["Không thể lưu: script đã chết (404/không tải được)."] = {"Cannot save: the script is dead (404 / cannot be downloaded).","Não foi possível salvar: o script está morto (404 / não pode ser baixado)."},
    ["Đã lưu nhưng script bị lỗi cú pháp — hãy cân nhắc trước khi chạy."] = {"Saved, but the script has a syntax error — think twice before running it.","Salvo, mas o script tem um erro de sintaxe — pense bem antes de executar."},
    ["Chưa chọn script nào!"] = {"No script selected!","Nenhum script selecionado!"},
    ["Hoạt động"] = {"Working","Funcionando"},
    ["Lỗi cú pháp"] = {"Syntax error","Erro de sintaxe"},
    ["Link không hợp lệ"] = {"Invalid link","Link inválido"},
    ["Chưa kiểm tra"] = {"Not checked yet","Ainda não verificado"},
    ["Trạng thái: "] = {"Status: ","Status: "},
    ["Link: "] = {"Link: ","Link: "},
    ["chưa bao giờ"] = {"never","nunca"},
    ["Đã xóa: "] = {"Deleted: ","Excluído: "},
    ["Đã copy link script."] = {"Script link copied.","Link do script copiado."},
    ["Danh sách trống."] = {"The list is empty.","A lista está vazia."},
    ["Đã xuất mã đồng bộ (%d script) và copy vào clipboard."] = {"Exported sync code (%d scripts) and copied it to the clipboard.","Código de sincronização exportado (%d scripts) e copiado para a área de transferência."},
    ["Executor không hỗ trợ copy — mã đã được in ra console (F9)."] = {"Executor does not support copy — the code was printed to the console (F9).","O executor não suporta cópia — o código foi impresso no console (F9)."},
    ["Mã đồng bộ không hợp lệ hoặc bị lỗi."] = {"Invalid or corrupted sync code.","Código de sincronização inválido ou corrompido."},
    ["Đã nhập %d script mới (bỏ qua %d trùng)."] = {"Imported %d new script(s) (%d duplicates skipped).","%d novo(s) script(s) importado(s) (%d duplicado(s) ignorado(s))."},
    ["Không tải được nội dung từ link."] = {"Could not download content from the link.","Não foi possível baixar o conteúdo do link."},
    ["Đã kiểm tra %d script: %d hoạt động, %d lỗi."] = {"Checked %d script(s): %d working, %d failing.","%d script(s) verificado(s): %d funcionando, %d com falha."},
    ["Không thể ghi file — dữ liệu chỉ lưu tạm trong phiên này."] = {"Cannot write the file — data is only kept for this session.","Não foi possível gravar o arquivo — os dados ficam só nesta sessão."},
    ["Đang kiểm tra tất cả script..."] = {"Checking all scripts...","Verificando todos os scripts..."},
    ["Đã lưu link tự động đồng bộ."] = {"Auto-sync link saved.","Link de sincronização automática salvo."},
    ["Hãy lưu script của bạn muốn lưu vào đây!"] = {"Save your script here!","Salve seus scripts aqui!"},
    ["Đã nhận diện link: "] = {"Detected link: ","Link detectado: "},
    ["Mã chạy: "] = {"Run code: ","Código de execução: "},
    ["📋 Copy loadstring"] = {"📋 Copy loadstring","📋 Copiar loadstring"},
    ["Đã copy loadstring vào clipboard!"] = {"loadstring copied to clipboard!","loadstring copiado para a área de transferência!"},
    ["🎯 Chỉ phát bài Yêu thích khi tự chuyển bài"] = {"🎯 Only play Favorites when auto-advancing","🎯 Tocar só Favoritas ao avançar automaticamente"},
    ["Chưa có bài Yêu thích nào!"] = {"No Favorite songs yet!","Ainda não há músicas Favoritas!"},
    ["Game chưa tải xong, chờ chút..."] = {"Game is still loading, please wait...","O jogo ainda está carregando, aguarde..."},
    ["Game sẵn sàng, đang khởi chạy..."] = {"Game ready, starting...","Jogo pronto, iniciando..."},
    ["🎉 Welcome"] = {"🎉 Welcome","🎉 Bem-vindo"},
    ["Logger sẵn sàng."] = {"Logger ready.","Logger pronto."},
    ["Khởi động..."] = {"Starting...","Iniciando..."},
    ["💡 Menu tự nhận diện game."] = {"💡 The menu detects your game automatically.","💡 O menu detecta seu jogo automaticamente."},
    ["💡 Tab Khác chạy được ở mọi game."] = {"💡 The General tab works in every game.","💡 A aba Outros funciona em qualquer jogo."},
    ["💡 Tab Nhạc để nghe khi chơi."] = {"💡 The Music tab plays music while you play.","💡 A aba Música toca músicas enquanto você joga."},
    ["Đang tải, chờ chút..."] = {"Loading, please wait...","Carregando, aguarde..."},
    ["Chức năng"] = {"Features","Recursos"},
    ["  Tìm script"] = {"  Find script","  Buscar script"},
    ["Tên hub, rồi Enter"] = {"Hub name, then Enter","Nome do hub, depois Enter"},
    ["   Chế độ copy script"] = {"   Copy-script mode","   Modo copiar script"},
    [" Đã bật nhưng hết lượt copy!"] = {" On, but no copies left!"," Ativado, mas sem cópias restantes!"},
    [" Đã bật: bấm nút để copy ("] = {" On: tap to copy ("," Ativado: toque para copiar ("},
    [" lượt còn)"] = {" left)"," restantes)"},
    [" Đã tắt: bấm nút để chạy luôn"] = {" Off: tap to run directly"," Desativado: toque para executar direto"},
    ["Nhạc"] = {"Music","Música"},
    ["Trình phát"] = {"Player","Player"},
    ["🔊 Âm lượng"] = {"🔊 Volume","🔊 Volume"},
    ["👁️ HUD nhạc"] = {"👁️ Music HUD","👁️ HUD de música"},
    ["🔁 Lặp bài này"] = {"🔁 Repeat song","🔁 Repetir música"},
    ["Đã bật lặp bài!"] = {"Repeat on!","Repetição ativada!"},
    ["Đã tắt lặp bài."] = {"Repeat off.","Repetição desativada."},
    ["🛑 Dừng nhạc"] = {"🛑 Stop music","🛑 Parar música"},
    ["Đã dừng nhạc!"] = {"Music stopped!","Música parada!"},
    ["Chưa có nhạc đang phát."] = {"Nothing is playing.","Nada está tocando."},
    ["Thư viện"] = {"Library","Biblioteca"},
    ["Chọn bài"] = {"Pick a song","Escolha uma música"},
    ["Lọc bài hát"] = {"Filter songs","Filtrar músicas"},
    ["Gõ để tìm..."] = {"Type to search...","Digite para buscar..."},
    ["❌ Không có kết quả"] = {"❌ No results","❌ Sem resultados"},
    ["Phát theo ID"] = {"Play by ID","Tocar por ID"},
    ["Sound ID"] = {"Sound ID","Sound ID"},
    ["▶ Phát ID"] = {"▶ Play ID","▶ Tocar ID"},
    ["Nhập ID nhạc trước!"] = {"Enter a music ID first!","Digite um ID de música primeiro!"},
    ["ID nhạc không dùng được."] = {"That music ID can't be used.","Esse ID de música não pode ser usado."},
    ["✉️ Góp ý"] = {"✉️ Feedback","✉️ Feedback"},
    ["Gửi góp ý"] = {"Send feedback","Enviar feedback"},
    ["Nội dung góp ý..."] = {"Your feedback...","Seu feedback..."},
    ["Nhập nội dung trước khi gửi."] = {"Write something first.","Escreva algo primeiro."},
    ["Người gửi"] = {"Sender","Remetente"},
    ["ID người gửi"] = {"Sender ID","ID do remetente"},
    ["Tối ưu"] = {"Optimize","Otimizar"},
    ["Hiệu suất"] = {"Performance","Desempenho"},
    ["📉 Giảm đồ họa"] = {"📉 Low graphics","📉 Gráficos baixos"},
    ["Đã giảm đồ họa — bấm Khôi phục để trả lại."] = {"Graphics lowered — tap Restore to revert.","Gráficos reduzidos — toque em Restaurar para reverter."},
    ["Đang dọn đồ họa (vài giây)..."] = {"Cleaning graphics (a few seconds)...","Limpando gráficos (alguns segundos)..."},
    ["♻️ Khôi phục"] = {"♻️ Restore","♻️ Restaurar"},
    ["🧹 Dọn chat"] = {"🧹 Clean chat","🧹 Limpar chat"},
    [" FPS / Ping"] = {" FPS / Ping"," FPS / Ping"},
    ["Máy chủ"] = {"Server","Servidor"},
    ["🔍 Server vắng nhất"] = {"🔍 Emptiest server","🔍 Servidor mais vazio"},
    ["JobID"] = {"JobID","JobID"},
    ["Dán JobID..."] = {"Paste JobID...","Cole o JobID..."},
    ["Vào server"] = {"Join server","Entrar no servidor"},
    ["🗂️ Xuất danh sách server"] = {"🗂️ Export servers","🗂️ Exportar servidores"},
    ["Nhật ký trực tiếp"] = {"Live log","Log ao vivo"},
    ["Lọc log mini"] = {"Mini log filter","Filtro do mini log"},
    ["📋 Copy log"] = {"📋 Copy log","📋 Copiar log"},
    ["💾 Lưu log"] = {"💾 Save log","💾 Salvar log"},
    ["🗑️ Xoá log"] = {"🗑️ Clear log","🗑️ Limpar log"},
    ["Dòng chảy nhật ký"] = {"Log stream","Fluxo do log"},
    ["Chế độ soi log"] = {"Log lens","Lupa do log"},
    ["◎ Xem tất tần tật"] = {"◎ Show everything","◎ Mostrar tudo"},
    ["✖ Chỉ bắt lỗi"] = {"✖ Errors only","✖ Só erros"},
    ["⚠ Cảnh báo trở lên"] = {"⚠ Warnings and up","⚠ Avisos ou mais"},
    ["✔ Chỉ việc êm xuôi"] = {"✔ Smooth ones only","✔ Só os sucessos"},
    ["🖥 Mở bảng F9 / F12"] = {"🖥 Open F9 / F12 panel","🖥 Abrir painel F9 / F12"},
    ["📎 Chép log vào bộ nhớ tạm"] = {"📎 Copy log to clipboard","📎 Copiar log para a área de transferência"},
    ["📥 Cất log ra file"] = {"📥 Stash log to file","📥 Guardar log em arquivo"},
    ["🧹 Quét sạch log"] = {"🧹 Sweep log clean","🧹 Varrer o log"},
    ["🪟 Khung log nổi"] = {"🪟 Floating log box","🪟 Caixa de log flutuante"},
    ["Đã mở bảng F9/F12 của Roblox."] = {"Roblox F9/F12 panel opened.","Painel F9/F12 do Roblox aberto."},
    ["Không mở được F9/F12 trên executor này."] = {"Could not open F9/F12 on this executor.","Não foi possível abrir o F9/F12 neste executor."},
    ["Đã đóng bảng F9/F12 của Roblox."] = {"Roblox F9/F12 panel closed.","Painel F9/F12 do Roblox fechado."},
    ["Hệ thống"] = {"System","Sistema"},
    ["Anti-AFK"] = {"Anti-AFK","Anti-AFK"},
    ["Màn trắng (AFK)"] = {"White screen (AFK)","Tela branca (AFK)"},
    ["Màn đen (AFK)"] = {"Black screen (AFK)","Tela preta (AFK)"},
    ["🎨 Màu menu"] = {"🎨 Menu color","🎨 Cor do menu"},
    ["📋 Mini log"] = {"📋 Mini log","📋 Mini log"},
    ["Mini log: đang hiện"] = {"Mini log: shown","Mini log: visível"},
    ["Mini log: đã ẩn"] = {"Mini log: hidden","Mini log: oculto"},
    ["❌ Đóng menu"] = {"❌ Close menu","❌ Fechar menu"},
    ["Chi tiết"] = {"Details","Detalhes"},
    ["Game: "] = {"Game: ","Jogo: "},
    ["Anti-Kick: bật 🟢"] = {"Anti-Kick: on 🟢","Anti-Kick: ativo 🟢"},
    ["Chạy được: 00:00:00"] = {"Uptime: 00:00:00","Tempo ativo: 00:00:00"},
    ["Chạy được: %02d:%02d:%02d"] = {"Uptime: %02d:%02d:%02d","Tempo ativo: %02d:%02d:%02d"},
    [" Discord"] = {" Discord"," Discord"},
    ["Đã copy link Discord!"] = {"Discord link copied!","Link do Discord copiado!"},
    ["Đã copy rồi!"] = {"Already copied!","Já copiado!"},
    [" TikTok"] = {" TikTok"," TikTok"},
    ["Đã copy link TikTok!"] = {"TikTok link copied!","Link do TikTok copiado!"},
    ["Kiểm tra bảo mật..."] = {"Checking security...","Verificando segurança..."},
    ["Tải tài nguyên..."] = {"Loading assets...","Carregando recursos..."},
    ["Nạp danh sách script..."] = {"Loading script list...","Carregando lista de scripts..."},
    ["Đồng bộ giao diện..."] = {"Syncing UI...","Sincronizando a UI..."},
    ["Hoàn tất..."] = {"Finishing up...","Finalizando..."},
    ["✨ Sẵn sàng!"] = {"✨ Ready!","✨ Pronto!"},
    ["Game chưa hỗ trợ. Xem script chung ở tab Khác."] = {"Game not supported yet. See the General tab.","Jogo ainda não suportado. Veja a aba Outros."},
    ["Kho script"] = {"Script vault","Cofre de scripts"},
    ["Thêm mới"] = {"Add new","Adicionar novo"},
    ["Tên"] = {"Name","Nome"},
    ["VD: Script của tôi"] = {"e.g. My script","ex.: Meu script"},
    ["💾 Lưu & kiểm tra"] = {"💾 Save & check","💾 Salvar e verificar"},
    ["Danh sách"] = {"List","Lista"},
    ["Chọn script"] = {"Pick script","Escolher script"},
    ["— Trống —"] = {"— Empty —","— Vazio —"},
    ["Chọn script để xem chi tiết."] = {"Pick a script to see details.","Escolha um script para ver os detalhes."},
    ["▶ Chạy"] = {"▶ Run","▶ Executar"},
    ["🔍 Kiểm tra"] = {"🔍 Check","🔍 Verificar"},
    ["🔍 Kiểm tra hết"] = {"🔍 Check all","🔍 Verificar todos"},
    ["🗑️ Xoá"] = {"🗑️ Delete","🗑️ Excluir"},
    ["Đồng bộ"] = {"Sync","Sincronizar"},
    ["Danh sách lưu ở x8k2/saved_scripts.json. Sang máy khác: xuất mã rồi nhập lại. Chỉ nhập từ nguồn tin cậy."] = {"Saved in x8k2/saved_scripts.json. On another device: export a code, then import it. Only import from sources you trust.","Salvo em x8k2/saved_scripts.json. Em outro dispositivo: exporte um código e depois importe. Importe apenas de fontes confiáveis."},
    ["📤 Xuất mã"] = {"📤 Export code","📤 Exportar código"},
    ["Mã hoặc link"] = {"Code or link","Código ou link"},
    ["📥 Nhập mã"] = {"📥 Import code","📥 Importar código"},
    ["Link tự đồng bộ"] = {"Auto-sync link","Link de sincronização automática"},
    ["Mỗi lần mở menu sẽ nhập thêm từ link này."] = {"Scripts from this link are merged in each time the menu opens.","Os scripts deste link são mesclados toda vez que o menu abre."},
    ["Link chết (404)"] = {"Dead link (404)","Link morto (404)"},
    ["Kiểm tra: "] = {"Checked: ","Verificado: "},
    ["Link / loadstring"] = {"Link / loadstring","Link / loadstring"},
    ["Không thấy link https trong nội dung!"] = {"No https link found!","Nenhum link https encontrado!"},
    ["Điều khiển"] = {"Controls","Controles"},
    ["🎧 Chưa phát gì"] = {"🎧 Idle","🎧 Parado"},
    ["⏮ Trước"] = {"⏮ Prev","⏮ Anterior"},
    ["⏯ Tạm dừng"] = {"⏯ Pause / Play","⏯ Pausar / Tocar"},
    ["⏭ Tiếp"] = {"⏭ Next","⏭ Próxima"},
    ["⏪ Lùi 10s"] = {"⏪ Back 10s","⏪ Voltar 10s"},
    ["⏩ Tới 10s"] = {"⏩ Forward 10s","⏩ Avançar 10s"},
    ["🎲 Ngẫu nhiên"] = {"🎲 Random","🎲 Aleatório"},
    ["⚡ Tốc độ"] = {"⚡ Speed","⚡ Velocidade"},
    ["🔀 Trộn bài"] = {"🔀 Shuffle","🔀 Embaralhar"},
    ["⏲ Hẹn giờ (phút)"] = {"⏲ Sleep timer (min)","⏲ Timer de sono (min)"},
    ["Nhạc tắt sau %d phút."] = {"Music stops in %d min.","A música para em %d min."},
    ["🔁 Đổi server"] = {"🔁 Hop server","🔁 Trocar servidor"},
    ["⤴️ Vào lại"] = {"⤴️ Rejoin","⤴️ Reentrar"},
    ["Cộng đồng"] = {"Community","Comunidade"},
    ["Góp ý"] = {"Feedback","Feedback"},
    ["Chào mừng"] = {"Welcome","Bem-vindo"},
    ["Trực tiếp"] = {"Live","Ao vivo"},
    ["Chào buổi sáng"] = {"Good morning","Bom dia"},
    ["Chào buổi chiều"] = {"Good afternoon","Boa tarde"},
    ["Chào buổi tối"] = {"Good evening","Boa noite"},
    ["Khuya rồi, nghỉ sớm nhé"] = {"It's late, get some rest","Já é tarde, vá descansar"},
    ["✨ H — script gọn, chạy mượt"] = {"✨ H — clean scripts, smooth play","✨ H — scripts enxutos, jogo fluido"},
    ["🚀 Tự nhận game, nạp đúng script"] = {"🚀 Detects your game, loads the right scripts","🚀 Detecta seu jogo e carrega os scripts certos"},
    ["🎵 Có sẵn trình phát nhạc trong menu"] = {"🎵 A music player built into the menu","🎵 Um player de música dentro do menu"},
    ["💾 Lưu script, đồng bộ sang máy khác"] = {"💾 Save scripts, sync to another device","💾 Salve scripts e sincronize com outro dispositivo"},
    ["🛡️ Anti-AFK, tăng FPS, dọn chat"] = {"🛡️ Anti-AFK, FPS boost, chat cleaner","🛡️ Anti-AFK, mais FPS, limpeza de chat"},
    ["Có gì trong H?"] = {"What's inside H?","O que tem no H?"},
    ["• Script riêng cho từng game\n• Trình phát nhạc + HUD kéo thả\n• Kho script: lưu và đồng bộ máy khác\n• Tối ưu FPS, dọn chat, đổi server nhanh"] = {"• Dedicated scripts for each game\n• Music player + draggable HUD\n• Script vault: save and sync to other devices\n• FPS boost, chat cleaner, quick server hop","• Scripts dedicados para cada jogo\n• Player de música + HUD arrastável\n• Cofre de scripts: salve e sincronize com outros dispositivos\n• Mais FPS, limpeza de chat, troca rápida de servidor"},
    ["Server chạy: "] = {"Server up: ","Servidor ativo: "},
    ["người chơi"] = {"players","jogadores"},
    ["Phiên bản: "] = {"Version: ","Versão: "},
    [" Pháo hoa"] = {" Confetti"," Confete"},
    ["Module"] = {"Modules","Módulos"},
    ["Thông tin trực tiếp"] = {"Live info","Info ao vivo"},
    ["Sẵn sàng"] = {"Ready","Pronto"},
    ["Ngôn ngữ"] = {"Language","Idioma"},
    ["Tiến trình kiểm tra"] = {"Check progress","Progresso da verificação"},
    ["Tiến trình nhập"] = {"Import progress","Progresso da importação"},
    ["Tiến trình thu thập server"] = {"Server fetch progress","Progresso da coleta de servidores"},
    ["👁️ Ẩn tên người chơi (Mask)"] = {"👁️ Hide player name (Mask)","👁️ Ocultar nome do jogador (Máscara)"},
    ["🎨 Giao diện Menu (Theme)"] = {"🎨 Menu theme","🎨 Tema do menu"},
    ["🎨 Default: mặc định (kính) · Cobalt: xanh đậm · Ember: cam cháy · Amethyst: tím · Frost: băng giá · Rose: hồng"] = {"🎨 Default: default (glass) · Cobalt: deep blue · Ember: burnt orange · Amethyst: purple · Frost: icy · Rose: pink","🎨 Default: padrão (vidro) · Cobalt: azul-escuro · Ember: laranja queimado · Amethyst: roxo · Frost: gelo · Rose: rosa"},
    ["🎨 Đã đổi giao diện: "] = {"🎨 Theme changed: ","🎨 Tema alterado: "},
    ["🛡️ Anti-AFK"] = {"🛡️ Anti-AFK","🛡️ Anti-AFK"},
    ["🔄 Tự động vào lại khi bị đá"] = {"🔄 Auto rejoin when kicked","🔄 Reentrar automaticamente se expulso"},
    ["Anti-AFK: đã bật (di chuyển nhân vật nhẹ nhàng, an toàn cho Anti-Cheat)"] = {"Anti-AFK: enabled (gentle character movement, Anti-Cheat safe)","Anti-AFK: ativado (movimento leve do personagem, seguro para Anti-Cheat)"},
    ["Auto Rejoin: Đã thử lại 3 lần. Tự động tắt để tránh bị ban."] = {"Auto Rejoin: Retried 3 times. Turned off automatically to avoid a ban.","Auto Rejoin: 3 tentativas feitas. Desativado automaticamente para evitar banimento."},
    ["☄️ Bật Auto-run khi vào game"] = {"☄️ Enable Auto-run on join","☄️ Ativar Auto-run ao entrar no jogo"},
    ["☄️ Tự động chạy"] = {"☄️ Auto-run","☄️ Execução automática"},
    ["☄️ Đã bật (Bấm để tắt)"] = {"☄️ Enabled (tap to turn off)","☄️ Ativado (toque para desligar)"},
    ["🗑️ Tắt Auto-run script đang chọn"] = {"🗑️ Turn off Auto-run for the selected script","🗑️ Desativar Auto-run do script selecionado"},
    ["☄️ Script đang Auto-run"] = {"☄️ Auto-run scripts","☄️ Scripts em Auto-run"},
    ["— Chưa có script Auto-run —"] = {"— No Auto-run scripts —","— Nenhum script em Auto-run —"},
    ["☄️ Đã bật Auto-run: "] = {"☄️ Auto-run on: ","☄️ Auto-run ativado: "},
    ["☄️ Đã tắt Auto-run: "] = {"☄️ Auto-run off: ","☄️ Auto-run desativado: "},
    ["☄️ Chưa có script Auto-run nào."] = {"☄️ No Auto-run scripts yet.","☄️ Nenhum script em Auto-run ainda."},
    ["☄️ Đang Auto-run: "] = {"☄️ Auto-running: ","☄️ Em Auto-run: "},
    ["☄️ Tự động chạy (Auto-run)"] = {"☄️ Auto-run","☄️ Execução automática (Auto-run)"},
    ["Fix lag"] = {"Fix lag","Corrigir lag"}, -- [V36]
    ["Giảm đồ họa"] = {"Low graphics","Gráficos baixos"}, -- [V36]
    ["Dọn chat"] = {"Clean chat","Limpar chat"}, -- [V36]
    ["Tìm"] = {"Search","Pesquisar"}, -- [V36]
    ["Tải lại"] = {"Reload","Recarregar"}, -- [V36]
    ["Trang trước"] = {"Previous page","Página anterior"}, -- [V36]
    ["Trang sau"] = {"Next page ","Próxima página "}, -- [V36]
    ["Copy Loadstring"] = {"Copy loadstring","Copiar loadstring"}, -- [V36]
    ["Copy loadstring"] = {"Copy loadstring","Copiar loadstring"}, -- [V36]
    ["Lưu vào Kho"] = {"Save to vault","Salvar no cofre"}, -- [V36]
    ["Lưu & kiểm tra"] = {"Save & check","Salvar e verificar"}, -- [V36]
    ["Kiểm tra"] = {"Check","Verificar"}, -- [V36]
    ["Kiểm tra hết"] = {"Check all","Verificar todos"}, -- [V36]
    ["Xuất mã"] = {"Export code","Exportar código"}, -- [V36]
    ["Nhập mã"] = {"Import code","Importar código"}, -- [V36]
    ["Đã bật (bấm để tắt)"] = {"Enabled (tap to turn off)","Ativado (toque para desligar)"}, -- [V36]
    ["Chạy Auto-run ngay"] = {"Run Auto-run now","Executar Auto-run agora"}, -- [V36]
    ["Tắt Auto-run script đang chọn"] = {"Turn off Auto-run for the selected script","Desativar Auto-run do script selecionado"}, -- [V36]
    ["Bỏ ghim tất cả"] = {"Unpin all","Desafixar tudo"}, -- [V36]
    ["Đóng menu"] = {"Close menu","Fechar menu"}, -- [V36]
    ["Tự động vào lại khi bị đá"] = {"Auto rejoin when kicked","Reentrar automaticamente se expulso"}, -- [V36]
    ["Ẩn tên người chơi (Mask)"] = {"Hide player name (Mask)","Ocultar nome do jogador (Máscara)"}, -- [V36]
    ["Giao diện Menu (Theme)"] = {"Menu theme","Tema do menu"}, -- [V36]
    ["Trước"] = {"Prev","Anterior"}, -- [V36]
    ["Phát/Tạm dừng"] = {"Play/Pause","Tocar/Pausar"}, -- [V36]
    ["Tiếp"] = {"Next","Próxima"}, -- [V36]
    ["Lùi 10s"] = {"Back 10s","Voltar 10s"}, -- [V36]
    ["Tới 10s"] = {"Forward 10s","Avançar 10s"}, -- [V36]
    ["Ngẫu nhiên"] = {"Random","Aleatório"}, -- [V36]
    ["Tốc độ"] = {"Speed","Velocidade"}, -- [V36]
    ["Trộn bài"] = {"Shuffle","Embaralhar"}, -- [V36]
    ["Hẹn giờ (phút)"] = {"Sleep timer (min)","Timer de sono (min)"}, -- [V36]
    ["Âm lượng"] = {"Volume","Volume"}, -- [V36]
    ["HUD nhạc"] = {"Music HUD","HUD de música"}, -- [V36]
    ["Lặp bài này"] = {"Repeat song","Repetir música"}, -- [V36]
    ["Dừng nhạc"] = {"Stop music","Parar música"}, -- [V36]
    ["Bấm Tải lại để tải danh sách script mới nhất."] = {"Press Reload to load the latest scripts.","Toque em Recarregar para carregar os scripts mais recentes."}, -- [V36]
    ["Chú thích: đã xác minh · cần key · game · lượt xem"] = {"Legend: verified · needs key · game · views","Legenda: verificado · precisa de key · jogo · visualizações"}, -- [V36]
    ["PlaceID: "] = {"PlaceID: ","PlaceID: "}, -- [V36]
    ["Job: "] = {"Job: ","Job: "}, -- [V36]
    ["Executor: "] = {"Executor: ","Executor: "}, -- [V36]
    ["Khu vực / Region: "] = {"Region: ","Região: "}, -- [V36]
    ["Default: mặc định (kính) · Cobalt: xanh đậm · Ember: cam cháy · Amethyst: tím · Frost: băng giá · Rose: hồng"] = {"Default: default (glass) · Cobalt: deep blue · Ember: burnt orange · Amethyst: purple · Frost: icy · Rose: pink","Default: padrão (vidro) · Cobalt: azul-escuro · Ember: laranja queimado · Amethyst: roxo · Frost: gelo · Rose: rosa"}, -- [V36]
    ["Trang %d/%d • %d script"] = {"Page %d/%d • %d scripts","Página %d/%d • %d scripts"}, -- [V36]
    ["Lỗi tải"] = {"Load error","Erro ao carregar"}, -- [V36]
    ["Slug không hợp lệ!"] = {"Invalid slug!","Slug inválido!"}, -- [V36]
    ["Script này cần KEY! Bấm ▶ Chạy lần nữa để xác nhận."] = {"This script needs a KEY! Press ▶ Run again to confirm.","Este script precisa de KEY! Toque em ▶ Executar de novo para confirmar."}, -- [V36]
    ["Script này có thể đã bị Patched! Bấm ▶ Chạy lần nữa để xác nhận."] = {"This script may be patched! Press ▶ Run again to confirm.","Este script pode estar patcheado! Toque em ▶ Executar de novo para confirmar."}, -- [V36]
    ["Về Hub"] = {"About","Sobre"}, -- [V36]
    ["Tuỳ chỉnh"] = {"Customize","Personalizar"}, -- [V36]
    ["HiulzHub — gọn · mượt · không drama"] = {"HiulzHub — lean · smooth · no drama","HiulzHub — enxuto · suave · sem drama"}, -- [V36]
    ["Tự động chạy lại script đã bật khi đổi server"] = {"Auto-restart enabled scripts on server switch","Reiniciar scripts ativados ao trocar de servidor"},
    ["Khôi phục script?"] = {"Restore scripts?","Restaurar scripts?"},
    ["Bạn đã bật %d script từ danh sách script. Muốn tự động chạy lại khi vào server này?"] = {"You had %d script(s) running from the script list. Auto-run them on this server?","Você tinha %d script(s) rodando da lista. Executar de novo neste servidor?"},
    ["Chạy lại"] = {"Run again","Executar de novo"},
    ["Khi bật, các script bạn đã bấm Chạy sẽ được hỏi để chạy lại khi bạn vào server mới hoặc vào lại. Mặc định tắt."] = {"When on, scripts you ran will be offered to run again when you join a new server or rejoin. Off by default.","Quando ativado, os scripts que você executou serão oferecidos para rodar de novo ao entrar em um novo servidor ou voltar. Desativado por padrão."},
    ["Giữ phiên script"] = {"Script session keeper","Manter sessão de scripts"},
    ["Tự chạy lại ngay sau khi bị kick hoặc rớt mạng"] = {"Auto re-run right after kick or disconnect","Executar de novo logo após kick ou queda de conexão"},
    ["Khi bị kick hoặc mất kết nối, script đã giữ sẽ tự chạy lại ngay khi bạn vào server mới, không cần hỏi. Dùng cùng Tự động vào lại khi bị đá để chạy hoàn toàn tự động. Mặc định tắt."] = {"After a kick or lost connection, kept scripts run again as soon as you join a new server, no prompt. Use together with Auto rejoin when kicked for a fully automatic flow. Off by default.","Após um kick ou perda de conexão, os scripts mantidos rodam de novo assim que você entra em um novo servidor, sem perguntar. Use junto com Reentrar automaticamente se expulso para ficar totalmente automático. Desativado por padrão."},
    ["Xem danh sách đang giữ"] = {"Show kept scripts","Ver scripts mantidos"},
    ["Xoá danh sách đang giữ"] = {"Clear kept scripts","Limpar scripts mantidos"},
    ["Xoá danh sách giữ?"] = {"Clear kept list?","Limpar lista mantida?"},
    ["Các script sẽ không được chạy lại nữa. Script trong Kho và Auto-run không bị xoá."] = {"These scripts will no longer be re-run. Scripts in the vault and Auto-run are not deleted.","Esses scripts não serão mais executados de novo. Scripts do cofre e do Auto-run não são excluídos."},
    ["Đã xoá danh sách giữ phiên."] = {"Kept list cleared.","Lista mantida limpa."},
    ["Đang giữ %d script: "] = {"Keeping %d script(s): ","Mantendo %d script(s): "},
    ["Chưa giữ script nào. Bấm Chạy một script trong danh sách để được ghi nhận."] = {"No scripts kept yet. Run a script from the list to record it.","Nenhum script mantido ainda. Execute um script da lista para registrá-lo."},
    ["Đang giữ phiên — tự chạy lại sau khi bị kick"] = {"Session kept — re-runs after a kick","Sessão mantida — roda de novo após kick"},
    ["Hỏi chạy lại khi đổi server"] = {"Ask to re-run on server switch","Perguntar para rodar de novo ao trocar de servidor"},
    ["Chạy lại ngay khi bị kick"] = {"Re-run right after kick","Rodar de novo após kick"},
    ["Tự nạp lại hub khi đổi server"] = {"Auto reload hub on server switch","Recarregar o hub automaticamente ao trocar de servidor"},
    ["Khi bật, HiulzHub tự chạy lại ở server mới mỗi khi bạn đổi server, vào lại hoặc bị kick (cần executor hỗ trợ queue_on_teleport). Tắt nếu hub của bạn đã tự chạy bằng autoexec. Mặc định bật."] = {"When on, HiulzHub runs itself again on the new server whenever you switch servers, rejoin or get kicked (needs an executor with queue_on_teleport). Turn off if your hub already runs via autoexec. On by default.","Quando ativado, o HiulzHub roda de novo sozinho no novo servidor sempre que você troca de servidor, volta ao jogo ou é expulso (requer executor com queue_on_teleport). Desative se o seu hub já roda via autoexec. Ativado por padrão."},
    ["Khi bị kick hoặc mất kết nối, script đã giữ (và hub nếu có đặt nguồn bên dưới) sẽ tự chạy lại khi bạn vào server mới, không cần hỏi. Dùng cùng Tự động vào lại khi bị đá để chạy hoàn toàn tự động. Mặc định tắt."] = {"After a kick or lost connection, kept scripts (and the hub, if you set a source below) run again when you join a new server, no prompt. Use together with Auto rejoin when kicked for a fully automatic flow. Off by default.","Após um kick ou perda de conexão, os scripts mantidos (e o hub, se você definir uma origem abaixo) rodam de novo ao entrar em um novo servidor, sem perguntar. Use junto com Reentrar automaticamente se expulso para ficar totalmente automático. Desativado por padrão."},
    ["Link hoặc file hub"] = {"Hub link or file","Link ou arquivo do hub"},
    ["https://... hoặc tên file .lua"] = {"https://... or .lua file name","https://... ou nome do arquivo .lua"},
    ["Dán link tải hub (https) hoặc tên file hub trong thư mục workspace của executor, rồi Enter. Hub được nạp lại từ nguồn này ở server mới. Để trống = dùng link mặc định của HiulzHub."] = {"Paste the hub download link (https) or the hub file name in your executor's workspace folder, then press Enter. The hub is reloaded from this source on the new server. Leave empty to use the default HiulzHub link.","Cole o link de download do hub (https) ou o nome do arquivo do hub na pasta workspace do executor e pressione Enter. O hub é recarregado desta origem no novo servidor. Deixe vazio para usar o link padrão do HiulzHub."},
    ["Đã lưu nguồn hub."] = {"Hub source saved.","Origem do hub salva."},
    ["Đã xoá nguồn hub."] = {"Hub source cleared.","Origem do hub removida."},
    ["Nguồn hub không hợp lệ. Dùng link https hoặc tên file trong workspace."] = {"Invalid hub source. Use an https link or a file name in the workspace.","Origem do hub inválida. Use um link https ou um nome de arquivo no workspace."},
  }
  local EXACT_ONLY = {
    ["Nguồn: ScriptBlox.com"] = true,
    ["ℹ️ Script do cộng đồng ScriptBlox đăng tải, không phải của HiulzHub. Hãy cân nhắc trước khi chạy — script chỉ chạy khi bạn bấm ▶ Chạy."] = true,
    ["Tìm kiếm"] = true,
    ["Tìm script trên ScriptBlox..."] = true,
    ["🔍 Tìm"] = true,
    ["🔄 Tải lại"] = true,
    ["Bộ lọc"] = true,
    ["Chỉ script đã xác minh (Verified)"] = true,
    ["Chỉ script không cần key"] = true,
    ["Chỉ script đa năng (Universal)"] = true,
    ["Danh sách script"] = true,
    ["Tiến trình tải ScriptBlox"] = true,
    ["Bấm 🔄 Tải lại để tải danh sách script mới nhất."] = true,
    ["— Chưa có dữ liệu —"] = true,
    ["⬅ Trang trước"] = true,
    ["Trang sau ➡"] = true,
    ["Chọn một script ở trên để xem chi tiết."] = true,
    ["📋 Copy Loadstring"] = true,
    ["Chú thích: ✅ đã xác minh · 🔑 cần key · 🎮 game · 👁 lượt xem"] = true,
    ["⏳ Đang tải từ ScriptBlox..."] = true,
    ["Đang tải từ ScriptBlox..."] = true,
    ["❌ Lỗi tải"] = true,
    ["Đã tải %d script (trang %d/%d)"] = true,
    ["📄 Trang %d/%d • %d script"] = true,
    ["Không có script nào phù hợp."] = true,
    ["Không tải được dữ liệu từ ScriptBlox: "] = true,
    ["Đang ở trang đầu."] = true,
    ["Đang ở trang cuối."] = true,
    ["Tiêu đề: "] = true,
    ["Lượt xem: "] = true,
    ["Lượt chạy: "] = true,
    ["Loại: "] = true,
    ["Ngày tạo: "] = true,
    ["Script này có thể đã bị Patched."] = true,
    ["Không chạy trên: "] = true,
    ["Link lấy key: "] = true,
    ["❌ Slug không hợp lệ!"] = true,
    ["⚠️ Script này cần KEY! Bấm ▶ Chạy lần nữa để xác nhận."] = true,
    ["⚠️ Script này có thể đã bị Patched! Bấm ▶ Chạy lần nữa để xác nhận."] = true,
    ["Đang tải script..."] = true,
    ["❌ Không tải được mã script: "] = true,
    ["✅ Đã chạy: "] = true,
    ["⭐ Ghim"] = true,
    ["💾 Lưu vào Kho"] = true,
    ["⭐ Đã ghim: "] = true,
    ["☆ Đã bỏ ghim: "] = true,
    [" — sẽ tự chạy khi khởi động"] = true,
    ["Danh sách ghim đã đầy (tối đa 20)."] = true,
    ["Link không hợp lệ."] = true,
    ["⭐ Đã ghim — tự chạy khi khởi động"] = true,
    ["Đã ghim — tự chạy khi khởi động"] = true,
    ["💾 Đã lưu vào Kho: "] = true,
    ["❌ Kho script chưa sẵn sàng."] = true,
    ["⭐ Đang tự chạy %d script đã ghim..."] = true,
    ["Phím tắt"] = true,
    ["⌨️ Phím tắt"] = true,
    ["👁 Ẩn/hiện menu"] = true,
    ["Mặc định: RightShift"] = true,
    ["🎵 Bật/tắt nhạc"] = true,
    ["Mặc định: M — chỉ có tác dụng khi đang có bài phát"] = true,
    ["Tự động chạy"] = true,
    ["⭐ Tự động chạy (script đã ghim)"] = true,
    ["⭐ Tự chạy script đã ghim khi khởi động"] = true,
    ["⭐ Chưa ghim script nào."] = true,
    ["🧹 Bỏ ghim tất cả"] = true,
    ["Đã bỏ ghim tất cả."] = true,
    ["Sẵn sàng"] = true,
    ["Ngôn ngữ"] = true,
    ["Tiến trình kiểm tra"] = true,
    ["Tiến trình nhập"] = true,
    ["Tiến trình thu thập server"] = true,
    ["👁️ Ẩn tên người chơi (Mask)"] = true,
    ["🎨 Giao diện Menu (Theme)"] = true,
    ["🎨 Default: mặc định (kính) · Cobalt: xanh đậm · Ember: cam cháy · Amethyst: tím · Frost: băng giá · Rose: hồng"] = true,
    ["🎨 Đã đổi giao diện: "] = true,
    ["🛡️ Anti-AFK"] = true,
    ["🔄 Tự động vào lại khi bị đá"] = true,
    ["Anti-AFK: đã bật (di chuyển nhân vật nhẹ nhàng, an toàn cho Anti-Cheat)"] = true,
    ["Auto Rejoin: Đã thử lại 3 lần. Tự động tắt để tránh bị ban."] = true,
    ["☄️ Bật Auto-run khi vào game"] = true,
    ["☄️ Tự động chạy"] = true,
    ["☄️ Đã bật (Bấm để tắt)"] = true,
    ["🗑️ Tắt Auto-run script đang chọn"] = true,
    ["☄️ Script đang Auto-run"] = true,
    ["— Chưa có script Auto-run —"] = true,
    ["☄️ Đã bật Auto-run: "] = true,
    ["☄️ Đã tắt Auto-run: "] = true,
    ["☄️ Chưa có script Auto-run nào."] = true,
    ["☄️ Đang Auto-run: "] = true,
    ["☄️ Tự động chạy (Auto-run)"] = true,
    ["Module"] = true,
    ["Chào mừng"] = true,
    ["Trực tiếp"] = true,
    ["Chào buổi tối"] = true,
    ["người chơi"] = true,
    [" Pháo hoa"] = true,
    ["🔁 Đổi server"] = true,
    ["⤴️ Vào lại"] = true,
    ["Cộng đồng"] = true,
    ["Góp ý"] = true,
    ["  Tìm script"] = true,
    [" Discord"] = true,
    [" TikTok"] = true,
    ["Anti-AFK"] = true,
    ["Chi tiết"] = true,
    ["Khác"] = true,
    ["Chưa kiểm tra"] = true,
    ["Chọn bài"] = true,
    ["Chọn bài hát..."] = true,
    ["Chọn script"] = true,
    ["Chức năng"] = true,
    ["Cài đặt"] = true,
    ["Danh sách"] = true,
    ["Dán JobID..."] = true,
    ["Gõ để tìm..."] = true,
    ["Gửi góp ý"] = true,
    ["Gửi thành công"] = true,
    ["Hiệu suất"] = true,
    ["Hoàn tất..."] = true,
    ["Hoạt động"] = true,
    ["Hệ thống"] = true,
    ["ID người gửi"] = true,
    ["JobID"] = true,
    ["Kho script"] = true,
    ["Khôi phục"] = true,
    ["Không Có"] = true,
    ["Không xác định"] = true,
    ["Khởi động..."] = true,
    ["Kiểm tra: "] = true,
    ["Link: "] = true,
    ["Lọc bài hát"] = true,
    ["Lọc log mini"] = true,
    ["Lỗi"] = true,
    ["Lỗi Webhook"] = true,
    ["Lỗi cú pháp"] = true,
    ["Lỗi gửi"] = true,
    ["Màn đen (AFK)"] = true,
    ["Máy chủ"] = true,
    ["Mã chạy: "] = true,
    ["Mã hoặc link"] = true,
    ["Người gửi"] = true,
    ["Nhân Vật"] = true,
    ["Nhạc"] = true,
    ["Nhật Ký"] = true,
    ["Nhật ký"] = true,
    ["Phát theo ID"] = true,
    ["Sound ID"] = true,
    ["Thành công"] = true,
    ["Thêm mới"] = true,
    ["Thông báo"] = true,
    ["Thông tin"] = true,
    ["Thư viện"] = true,
    ["Thời gian chạy"] = true,
    ["Trình phát"] = true,
    ["Trạng thái: "] = true,
    ["Tên"] = true,
    ["Tối ưu"] = true,
    ["Tối ưu (Auto)"] = true,
    ["Vui lòng đợi"] = true,
    ["Vào server"] = true,
    ["Xin chào, "] = true,
    ["[CẢNH BÁO]"] = true,
    ["[LỖI]"] = true,
    ["bạn"] = true,
    ["chưa bao giờ"] = true,
    ["Điều khiển"] = true,
    ["Đã copy rồi!"] = true,
    ["Đã dừng nhạc!"] = true,
    ["Đã lưu: "] = true,
    ["Đã nhận diện link: "] = true,
    ["Đã xóa: "] = true,
    ["Đồng bộ"] = true,
    ["— Trống —"] = true,
    [" FPS / Ping"] = true,
    ["⏩ Tới 10s"] = true,
    ["⏪ Lùi 10s"] = true,
    ["⏭ Tiếp"] = true,
    ["⏮ Trước"] = true,
    ["⏯ Tạm dừng"] = true,
    ["▶ Chạy"] = true,
    ["▶ Phát ID"] = true,
    ["♻️ Khôi phục"] = true,
    ["⚡ Tốc độ"] = true,
    ["✉️ Góp ý"] = true,
    ["✨ Sẵn sàng!"] = true,
    ["❌ Đóng menu"] = true,
    ["🎨 Màu menu"] = true,
    ["🎲 Ngẫu nhiên"] = true,
    ["👁️ HUD nhạc"] = true,
    ["💾 Lưu log"] = true,
    ["📉 Giảm đồ họa"] = true,
    ["📋 Copy log"] = true,
    ["📋 Mini log"] = true,
    ["📝 Nhật Ký"] = true,
    ["📤 Xuất mã"] = true,
    ["📥 Nhập mã"] = true,
    ["🔀 Trộn bài"] = true,
    ["🔁 Lặp bài này"] = true,
    ["🔊 Âm lượng"] = true,
    ["🔍 Kiểm tra"] = true,
    ["🗑️ Xoá"] = true,
    ["🗑️ Xoá log"] = true,
    ["🛑 Dừng nhạc"] = true,
    ["🧹 Dọn chat"] = true,
    ["Fix lag"] = true, -- [V36]
    ["Giảm đồ họa"] = true, -- [V36]
    ["Dọn chat"] = true, -- [V36]
    ["Tìm"] = true, -- [V36]
    ["Tải lại"] = true, -- [V36]
    ["Trang trước"] = true, -- [V36]
    ["Trang sau"] = true, -- [V36]
    ["Copy Loadstring"] = true, -- [V36]
    ["Copy loadstring"] = true, -- [V36]
    ["Lưu vào Kho"] = true, -- [V36]
    ["Lưu & kiểm tra"] = true, -- [V36]
    ["Kiểm tra"] = true, -- [V36]
    ["Kiểm tra hết"] = true, -- [V36]
    ["Xuất mã"] = true, -- [V36]
    ["Nhập mã"] = true, -- [V36]
    ["Đã bật (bấm để tắt)"] = true, -- [V36]
    ["Chạy Auto-run ngay"] = true, -- [V36]
    ["Tắt Auto-run script đang chọn"] = true, -- [V36]
    ["Bỏ ghim tất cả"] = true, -- [V36]
    ["Đóng menu"] = true, -- [V36]
    ["Tự động vào lại khi bị đá"] = true, -- [V36]
    ["Ẩn tên người chơi (Mask)"] = true, -- [V36]
    ["Giao diện Menu (Theme)"] = true, -- [V36]
    ["Trước"] = true, -- [V36]
    ["Phát/Tạm dừng"] = true, -- [V36]
    ["Tiếp"] = true, -- [V36]
    ["Lùi 10s"] = true, -- [V36]
    ["Tới 10s"] = true, -- [V36]
    ["Ngẫu nhiên"] = true, -- [V36]
    ["Tốc độ"] = true, -- [V36]
    ["Trộn bài"] = true, -- [V36]
    ["Hẹn giờ (phút)"] = true, -- [V36]
    ["Âm lượng"] = true, -- [V36]
    ["HUD nhạc"] = true, -- [V36]
    ["Lặp bài này"] = true, -- [V36]
    ["Dừng nhạc"] = true, -- [V36]
    ["Bấm Tải lại để tải danh sách script mới nhất."] = true, -- [V36]
    ["Chú thích: đã xác minh · cần key · game · lượt xem"] = true, -- [V36]
    ["PlaceID: "] = true, -- [V36]
    ["Job: "] = true, -- [V36]
    ["Executor: "] = true, -- [V36]
    ["Khu vực / Region: "] = true, -- [V36]
    ["Default: mặc định (kính) · Cobalt: xanh đậm · Ember: cam cháy · Amethyst: tím · Frost: băng giá · Rose: hồng"] = true, -- [V36]
    ["Trang %d/%d • %d script"] = true, -- [V36]
    ["Lỗi tải"] = true, -- [V36]
    ["Slug không hợp lệ!"] = true, -- [V36]
    ["Script này cần KEY! Bấm ▶ Chạy lần nữa để xác nhận."] = true, -- [V36]
    ["Script này có thể đã bị Patched! Bấm ▶ Chạy lần nữa để xác nhận."] = true, -- [V36]
    ["Về Hub"] = true, -- [V36]
    ["Tuỳ chỉnh"] = true, -- [V36]
    ["HiulzHub — gọn · mượt · không drama"] = true, -- [V36]
    ["Tự động chạy lại script đã bật khi đổi server"] = true,
    ["Khôi phục script?"] = true,
    ["Bạn đã bật %d script từ danh sách script. Muốn tự động chạy lại khi vào server này?"] = true,
    ["Chạy lại"] = true,
    ["Khi bật, các script bạn đã bấm Chạy sẽ được hỏi để chạy lại khi bạn vào server mới hoặc vào lại. Mặc định tắt."] = true,
    ["Giữ phiên script"] = true,
    ["Tự chạy lại ngay sau khi bị kick hoặc rớt mạng"] = true,
    ["Khi bị kick hoặc mất kết nối, script đã giữ sẽ tự chạy lại ngay khi bạn vào server mới, không cần hỏi. Dùng cùng Tự động vào lại khi bị đá để chạy hoàn toàn tự động. Mặc định tắt."] = true,
    ["Xem danh sách đang giữ"] = true,
    ["Xoá danh sách đang giữ"] = true,
    ["Xoá danh sách giữ?"] = true,
    ["Các script sẽ không được chạy lại nữa. Script trong Kho và Auto-run không bị xoá."] = true,
    ["Đã xoá danh sách giữ phiên."] = true,
    ["Đang giữ %d script: "] = true,
    ["Chưa giữ script nào. Bấm Chạy một script trong danh sách để được ghi nhận."] = true,
    ["Đang giữ phiên — tự chạy lại sau khi bị kick"] = true,
    ["Hỏi chạy lại khi đổi server"] = true,
    ["Chạy lại ngay khi bị kick"] = true,
    ["Tự nạp lại hub khi đổi server"] = true,
    ["Khi bật, HiulzHub tự chạy lại ở server mới mỗi khi bạn đổi server, vào lại hoặc bị kick (cần executor hỗ trợ queue_on_teleport). Tắt nếu hub của bạn đã tự chạy bằng autoexec. Mặc định bật."] = true,
    ["Khi bị kick hoặc mất kết nối, script đã giữ (và hub nếu có đặt nguồn bên dưới) sẽ tự chạy lại khi bạn vào server mới, không cần hỏi. Dùng cùng Tự động vào lại khi bị đá để chạy hoàn toàn tự động. Mặc định tắt."] = true,
    ["Link hoặc file hub"] = true,
    ["https://... hoặc tên file .lua"] = true,
    ["Dán link tải hub (https) hoặc tên file hub trong thư mục workspace của executor, rồi Enter. Hub được nạp lại từ nguồn này ở server mới. Để trống = dùng link mặc định của HiulzHub."] = true,
    ["Đã lưu nguồn hub."] = true,
    ["Đã xoá nguồn hub."] = true,
    ["Nguồn hub không hợp lệ. Dùng link https hoặc tên file trong workspace."] = true,
  }

  local FR = { {}, {} } -- [1] = English, [2] = Português (Brasil)
  for vi, t in pairs(TR) do
    if not EXACT_ONLY[vi] then
      table.insert(FR[1], { vi, t[1] })
      table.insert(FR[2], { vi, t[2] })
    end
  end
  for i = 1, 2 do table.sort(FR[i], function(a, b) return #a[1] > #b[1] end) end
  local MODES = { vi = true, en = true, pt = true, auto = true }

  local function replacePlain(s, from, to)
    return (s:gsub(from:gsub("%p", "%%%0"), (to:gsub("%%", "%%%%"))))
  end

  local function readMode()
    local mode = "auto"
    pcall(function()
      if type(isfile) == "function" and type(readfile) == "function" and isfile(CFG_FILE) then
        local d = HttpService:JSONDecode(readfile(CFG_FILE))
        if type(d) == "table" and MODES[d.mode] then mode = d.mode end
      end
    end)
    if MODES[_G.be46c0d7bfc3efb64] then
      if mode == "auto" then mode = _G.be46c0d7bfc3efb64 end
    end
    return mode
  end

  local function writeMode(mode)
    _G.be46c0d7bfc3efb64 = mode
    pcall(function()
      if type(writefile) ~= "function" then return end
      if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(CFG_DIR) then makefolder(CFG_DIR) end
      writefile(CFG_FILE, HttpService:JSONEncode({ mode = mode }))
    end)
  end

  local detected
  local function detect()
    if detected then return detected end
    local t0 = os.clock()
    while not Players.LocalPlayer and os.clock() - t0 < 10 do task.wait(0.1) end
    local lp = Players.LocalPlayer
    local code, source
    if lp then
      local done, ok, res = false, false, nil
      task.spawn(function()
        ok, res = pcall(function() return LocalizationService:GetCountryRegionForPlayerAsync(lp) end)
        done = true
      end)
      local t1 = os.clock()
      while not done and os.clock() - t1 < 4 do task.wait(0.05) end
      if done and ok and type(res) == "string" and res ~= "" then
        code, source = string.upper(res), "country"
      end
    end
    local loc
    pcall(function() loc = lp and lp.LocaleId end)
    if type(loc) ~= "string" or loc == "" then pcall(function() loc = LocalizationService.RobloxLocaleId end) end
    loc = string.lower(tostring(loc or ""))
    if not code then
      code = (loc:sub(1, 2) == "vi") and "VN" or (loc:sub(1, 2) == "pt") and "BR" or "??"
      source = "locale"
    end
    detected = { code = code, source = source, loc = loc }
    return detected
  end

  local lang
  local listeners = {}    -- gọi khi đổi ngôn ngữ: fn(lang, mode)
  local extraHooks = {}   -- gọi khi có bản dịch động mới: fn({ [vi] = en })
  local EXTRA = {}        -- bản dịch động (name_en / section_en / note_en / title_en từ scripts.json): [vi] = en
  local EXTRAP = {}       -- như EXTRA nhưng bản Português (name_pt ...): [vi] = pt; thiếu thì dùng bản English
  local XR = { {}, {} }   -- cụm con từ EXTRA (chỉ khoá có ký tự có dấu) để dịch tên script nằm trong thông báo ghép
  local function rebuildXR()
    XR = { {}, {} }
    for vi, e in pairs(EXTRA) do
      if #vi >= 4 and string.find(vi, "[\128-\255]") then
        table.insert(XR[1], { vi, e })
        table.insert(XR[2], { vi, EXTRAP[vi] or e })
      end
    end
    for i = 1, 2 do table.sort(XR[i], function(a, b) return #a[1] > #b[1] end) end
  end

  local function resolve()
    if lang then return lang end
    local mode = readMode()
    if mode == "vi" or mode == "en" or mode == "pt" then
      lang = mode
    else
      local d = detect()
      if d.code == "VN" then
        lang = "vi"
      elseif d.code == "BR" or tostring(d.loc or ""):sub(1, 2) == "pt" then
        lang = "pt"
      else
        lang = "en"
      end
    end
    return lang
  end

  -- Việt -> English (k = 1) / Português (k = 2): khớp nguyên chuỗi, sau đó thay cụm con cho chuỗi ghép động
  local function toLang(s, k)
    if type(s) ~= "string" or s == "" then return s end
    local t = TR[s]
    local e = (t and t[k]) or (k == 2 and EXTRAP[s]) or EXTRA[s]
    if e then return e end
    local fr, xr = FR[k], XR[k]
    for i = 1, #fr do
      local p = fr[i]
      if string.find(s, p[1], 1, true) then s = replacePlain(s, p[1], p[2]) end
    end
    for i = 1, #xr do
      local p = xr[i]
      if string.find(s, p[1], 1, true) then s = replacePlain(s, p[1], p[2]) end
    end
    return s
  end

  local function L(s)
    if type(s) ~= "string" or s == "" then return s end
    local l = resolve()
    if l == "vi" then return s end
    return toLang(s, l == "pt" and 2 or 1)
  end

  -- Đổi chế độ (vi / en / pt / auto): lưu file + áp dụng ngay + báo cho Window:SetLocale (Gen2)
  local function applyMode(mode)
    if not MODES[mode] then return resolve() end
    writeMode(mode)
    lang = nil
    local cur = resolve()
    for _, fn in ipairs(listeners) do pcall(fn, cur, mode) end
    return cur
  end

  -- [GEN2 LOCALIZATION] Nguồn của script là tiếng Việt, nên mỗi chuỗi Việt là một key;
  -- bảng `en` / `pt` chỉ liệt kê những chuỗi cần đổi. Locale "vi" không cần bảng (hiển thị đúng nguồn).
  local function pack()
    local en, pt = {}, {}
    for vi, t in pairs(TR) do en[vi] = t[1]; pt[vi] = t[2] end
    for vi, e in pairs(EXTRA) do en[vi] = e; pt[vi] = EXTRAP[vi] or e end
    return { en = en, pt = pt }
  end

  -- Resolver tuỳ chỉnh (source, localeId) -> string | nil. Chỉ xử lý tiếng Anh ("en", "en-us"...) và Bồ Đào Nha ("pt", "pt-br"...);
  -- trả nil để Gen2 rơi xuống bảng translations (kể cả gói do người dùng đăng ký thêm).
  local function translator(source, localeId)
    if type(source) ~= "string" then return nil end
    local base = string.match(string.lower(tostring(localeId or "")), "^(%a+)")
    local k = (base == "en" and 1) or (base == "pt" and 2) or nil
    if not k then return nil end
    local out = toLang(source, k)
    if out ~= source then return out end
    return nil
  end

  local function addExtra(map, mapPt)
    if type(map) ~= "table" then return end
    local added, addedP = {}, {}
    local any = false
    for vi, e in pairs(map) do
      if type(vi) == "string" and type(e) == "string" and vi ~= "" and e ~= vi then
        EXTRA[vi] = e
        added[vi] = e
        local p = type(mapPt) == "table" and mapPt[vi]
        EXTRAP[vi] = (type(p) == "string" and p ~= "") and p or nil
        addedP[vi] = EXTRAP[vi] or e
        any = true
      end
    end
    if any then
      rebuildXR()
      for _, fn in ipairs(extraHooks) do pcall(fn, added, addedP) end
    end
  end

  _G.tR9 = L
  _G.lG10 = resolve
  _G.lM11 = readMode
  _G.sL12 = applyMode
  _G.lI13 = function() return detect() end
  _G.tP18 = pack          -- Gen2: translations
  _G.tT19 = translator    -- Gen2: translator
  _G.oL16 = function(fn) if type(fn) == "function" then table.insert(listeners, fn) end end
  _G.rT17 = addExtra
  _G.hX20 = function(fn) if type(fn) == "function" then table.insert(extraHooks, fn) end end
end

-- [HỆ THỐNG KIỂM TRA TRẠNG THÁI GAME]
if not game:IsLoaded() then
  pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
      Title = "⏳ H",
      Text = _G.tR9("Game chưa tải xong, chờ chút..."),
      Duration = 10
    })
  end)

  game.Loaded:Wait()
  pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
      Title = "✅",
      Text = _G.tR9("Game sẵn sàng, đang khởi chạy..."),
      Duration = 5
    })
  end)
  task.wait(1)
end

-- ==========================================
-- [HỆ THỐNG KIỂM TRA RE-EXECUTE TOÀN CẦU]
-- ==========================================
local isReExecution = _G.e8aabebd23a37913d == true
_G.e8aabebd23a37913d = true

_G.d8e1181c0775aa002 = (_G.d8e1181c0775aa002 or 0) + 1
local currentExecute = _G.d8e1181c0775aa002

-- Tên instance ngẫu nhiên (cố định trong file để dọn được bản chạy trước)
local HzN = {
  hud = "fT8x3dsemN4", log = "v9ygFMWN4gy", sfx = "HVpivjyMwuH", music = "WkB1mnV2GxZ",
  confetti = "bHx3JfYX6SP", musichud = "bXATPTTmUuN", loading = "oFbyMm5rx8z",
  afk = "ZwGBfmyZw_", admin = "f1iuaytD8_", -- hai tên này có hậu tố số ngẫu nhiên
  blur = "kQ4zWm8LpVt",
  toast = "Qm4zT8xWk2P", -- [V35] ScreenGui của _G.HzToast
}
_G.HzBlurName = HzN.blur
local function HzOwn(name)
  if type(name) ~= "string" then return false end
  for k, v in pairs(HzN) do
    if k == "afk" or k == "admin" then
      if name:sub(1, #v) == v then return true end
    elseif name == v then
      return true
    end
  end
  return false
end

-- HỆ THỐNG TỰ ĐỘNG DỌN DẸP (ANTI-RE-EXECUTE) - ENHANCED
_G.HzCleanUp = function(fullWipe)
-- Vòng lặp destroy Sound giữ nguyên; bài sẽ được tạo lại bởi _G.HzMusicResume ở lần chạy mới.
pcall(function()
  if fullWipe then
    _G.HzMusicRuntime = nil
  elseif type(_G.HzMusicSnap) == "function" then
    _G.HzMusicSnap()
  end
  _G.HzMusicGen = (_G.HzMusicGen or 0) + 1 -- vòng watcher nhạc của lần chạy cũ thấy số đổi → tự thoát
end)
pcall(function()
  if type(_G.HzAntiAFK) == "function" then _G.HzAntiAFK(false) end
  if type(_G.HzAutoRejoin) == "function" then _G.HzAutoRejoin(false) end
end)
pcall(function() _G.HzRestorePromptedThisSession = false end)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

pcall(function()
  if settings and settings().Rendering then
    _G.originalQuality = (pcall(function() return settings().Rendering.QualityLevel end) and settings().Rendering.QualityLevel) or _G.originalQuality
  end
  if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
    _G.originalWalkSpeed = _G.originalWalkSpeed or LocalPlayer.Character.Humanoid.WalkSpeed
  end
  _G.originalBrightness = _G.originalBrightness or Lighting.Brightness
  _G.originalClockTime = _G.originalClockTime or Lighting.ClockTime
  _G.originalFogEnd = _G.originalFogEnd or Lighting.FogEnd
  _G.originalGlobalShadows = _G.originalGlobalShadows or Lighting.GlobalShadows
end)

pcall(function()
  for _, s in ipairs(SoundService:GetChildren()) do
    if s:IsA("Sound") and HzOwn(tostring(s.Name)) then
      pcall(function() if s.Playing then s:Stop() end end)
      pcall(function() s:Destroy() end)
    end
  end
  pcall(function()
    for _, e in ipairs(game:GetService("Lighting"):GetChildren()) do
      if e:IsA("BlurEffect") and HzOwn(e.Name) then e:Destroy() end
    end
  end)
end)

pcall(function()
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
      for _, part in ipairs(p.Character:GetDescendants()) do
        -- [PERF] chỉ BasePart (trừ HumanoidRootPart) + Decal/Texture
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
          pcall(function() part.Transparency = 0 end)
          pcall(function() if part:IsA("MeshPart") then part.TextureID = part.TextureID end end)
        elseif part:IsA("Decal") or part:IsA("Texture") then
          pcall(function() part.Transparency = 0 end)
        end
      end
    end
  end
end)

local function CleanOldElementsIn(parent)
  if not parent or not parent.GetChildren then return end
  for _, child in pairs(parent:GetChildren()) do
    local name = tostring(child.Name or "")
    if HzOwn(name) or name == "Rayfield" then
      pcall(function() child:Destroy() end)
    end
  end
end

pcall(function() CleanOldElementsIn(CoreGui) end)
pcall(function()
  if LocalPlayer then
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    CleanOldElementsIn(pg)
  end
end)

pcall(function()
  if _G.rW15 and type(_G.rW15.Unload) == "function" then pcall(function() _G.rW15:Unload() end) end
  _G.rW15 = nil
  if _G.rF14 then
    local rf = _G.rF14
    if type(rf) == "table" then
      if type(rf.Destroy) == "function" then pcall(rf.Destroy, rf) end
      if type(rf.Close) == "function" then pcall(rf.Close, rf) end
      if type(rf.Unload) == "function" then pcall(rf.Unload, rf) end
    elseif typeof(rf) == "Instance" then
      pcall(function() rf:Destroy() end)
    end
    _G.rF14 = nil
  end
end)

pcall(function()
  _G.b655ac11a998f805f = false
  if type(_G.dH6) == "function" then
    pcall(_G.dH6)
  end
  local hudName = HzN.hud
  pcall(function()
    local coreHud = CoreGui:FindFirstChild(hudName)
    if coreHud then coreHud:Destroy() end
  end)
  pcall(function()
    if LocalPlayer then
      local pg = LocalPlayer:FindFirstChild("PlayerGui")
      if pg then
        local hud = pg:FindFirstChild(hudName)
        if hud then hud:Destroy() end
      end
    end
  end)
end)

pcall(function()
  local toUnbind = {"ToggleHUD","SomeHotkeyAction","ToggleAFK","ToggleMusic","ToggleStatusHUD"}
  for _, name in ipairs(toUnbind) do
    pcall(function() ContextActionService:UnbindAction(name) end)
  end
end)

pcall(function()
  if type(_G._connections) == "table" then
    for k, v in pairs(_G._connections) do
      -- [V35] hash mới: key = conn; mảng cũ V34 (re-execute đè lên bản cũ): value = conn
      local conn = (typeof(k) == "RBXScriptConnection") and k or v
      pcall(function() if conn and conn.Disconnect then conn:Disconnect() end end)
      pcall(function() if conn and conn.disconnect then conn:disconnect() end end)
    end
    _G._connections = nil
  end
end)

pcall(function() _G.b655ac11a998f805f = false end)

pcall(function()
  if _G.HzGfxTouched == true then -- [PERF] chỉ khôi phục Lighting nếu người dùng đã bấm "Giảm đồ họa"
    if _G.originalBrightness ~= nil then Lighting.Brightness = _G.originalBrightness end
    if _G.originalClockTime ~= nil then Lighting.ClockTime = _G.originalClockTime end
    if _G.originalFogEnd ~= nil then Lighting.FogEnd = _G.originalFogEnd end
    if _G.originalGlobalShadows ~= nil then Lighting.GlobalShadows = _G.originalGlobalShadows end
  end
end)

pcall(function()
  local commonKeys = {"_functions","Functions","CloseFunctions","_listeners","_threads","_tasks","_loops","Connections","_modules","_widgets"}
  for _, key in ipairs(commonKeys) do
    local v = _G[key]
    if type(v) == "table" then
      for k, obj in pairs(v) do
        pcall(function()
          if type(obj) == "function" then pcall(obj) end
          if type(obj) == "table" then
            if type(obj.Destroy) == "function" then pcall(obj.Destroy, obj) end
            if type(obj.Close) == "function" then pcall(obj.Close, obj) end
            if type(obj.Unload) == "function" then pcall(obj.Unload, obj) end
            if type(obj.Disconnect) == "function" then pcall(obj.Disconnect, obj) end
            if type(obj.disconnect) == "function" then pcall(obj.disconnect, obj) end
          end
        end)
      end
    elseif type(v) == "function" then
      pcall(v)
    elseif typeof(v) == "Instance" then
      pcall(function() v:Destroy() end)
    end
    _G[key] = nil
  end
end)

pcall(function()
  local connKeys = {"_renderConn","_heartbeatConn","_steppedConn","_rendersteppedConn","_rsConn","_hbConn","_runConn","_loopConn"}
  for _, k in ipairs(connKeys) do
    local c = _G[k]
    if c then
      pcall(function() if c.Connected then c:Disconnect() end end)
      _G[k] = nil
    end
  end
end)

pcall(function()
  local function cleanGuiFor(parent)
    if not parent or not parent.GetDescendants then return end
    for _, inst in ipairs(parent:GetDescendants()) do
      local ok, name = pcall(function() return tostring(inst.Name) end)
      if ok and name and HzOwn(name) then
        pcall(function() if inst.Destroy then inst:Destroy() end end)
      end
    end
  end
  cleanGuiFor(CoreGui)
  if LocalPlayer then
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    cleanGuiFor(pg)
  end
end)

pcall(function()
  if type(_G._coroutines) == "table" then
    for _, co in ipairs(_G._coroutines) do
      pcall(function()
        if type(co) == "thread" then
          _G._shouldStop = true
        elseif type(co) == "function" then
          pcall(co)
        end
      end)
    end
    _G._coroutines = nil
  end
  if type(_G._threads) == "table" then
    _G._threads = nil
  end
end)

pcall(function()
  local clear = {"_AUTO_LOAD","_LOADER","_MUSIC_ID","_music","_tempGui","lG5","LoadUi"}
  for _, k in ipairs(clear) do _G[k] = nil end
  pcall(function() getgenv().LowGpu = nil end)
end)

pcall(function()
  for k, v in pairs(_G) do
    if type(k) == "string" and (k:lower():find("unload") or k:lower():find("close") or k:lower():find("destroy") or k:lower():find("stop")) then
      pcall(function() if type(v) == "function" then v() end end)
      _G[k] = nil
    end
  end
end)

if not isReExecution then
  pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
      Title = "HiulzHub", -- [FIX LANG]
      Text = _G.tR9("🎉 Welcome"),
      Duration = 4
    })
  end)
end

end
pcall(_G.HzCleanUp)

-- để người dùng dễ báo cáo. Không bao giờ ném lỗi; không có writefile thì chỉ ghi vào Nhật ký trong menu.
do
  local DIR, FILE, MAX_BYTES = "x8k2", "x8k2/error_log.txt", 60000
  _G.HzLogError = function(err, context)
    pcall(function()
      local msg = tostring(err == nil and "?" or err):gsub("%c+", " ")
      local ctx = tostring(context == nil and "?" or context):gsub("%c+", " ")
      local place = "?"
      pcall(function() place = tostring(game.PlaceId) end)
      local line = string.format("[%s] [V32-PC] [PlaceId %s] [%s] %s",
        os.date("%Y-%m-%d %H:%M:%S"), place, ctx:sub(1, 120), msg:sub(1, 1500))
      if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "📝 error_log: " .. ctx:sub(1, 60), "WARN") end
      if type(writefile) ~= "function" or type(readfile) ~= "function" or type(isfile) ~= "function" then return end
      if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(DIR) then makefolder(DIR) end
      local old = ""
      if isfile(FILE) then
        old = readfile(FILE)
        if type(old) ~= "string" then old = "" end
        if #old > MAX_BYTES then -- giữ nửa cuối, cắt tại đầu dòng
          old = old:sub(-math.floor(MAX_BYTES / 2))
          local nl = old:find("\n", 1, true)
          old = nl and old:sub(nl + 1) or ""
        end
      end
      writefile(FILE, old .. line .. "\n")
    end)
  end
end

----------------------------------------------------------------
-- [HỆ THỐNG NHẬT KÝ BẢO MẬT (OBFUSCATOR-SAFE LOGGER)]
----------------------------------------------------------------
task.spawn(function()
  pcall(function()
    local CoreGui = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")

    local MAX_BUFFER, MAX_ROWS, FLUSH_DELAY = ((_G.HzConst or {}).log or {}).maxBuffer or 500, ((_G.HzConst or {}).log or {}).maxRows or 80, ((_G.HzConst or {}).log or {}).flushDelay or 0.15 -- [V35]
    local LEVELS = {
      DEBUG   = { prefix = "[DEBUG]",      color = Color3.fromRGB(140, 140, 160) },
      INFO    = { prefix = "[INFO]",       color = Color3.fromRGB(200, 200, 200) },
      SUCCESS = { prefix = "[THÀNH CÔNG]", key = "[THÀNH CÔNG]", color = Color3.fromRGB(80, 255, 80) },
      WARN    = { prefix = "[CẢNH BÁO]", key = "[CẢNH BÁO]", color = Color3.fromRGB(255, 200, 0) },
      ERROR   = { prefix = "[LỖI]", key = "[LỖI]", color = Color3.fromRGB(255, 80, 80) },
    }
    local FILTERS = {
      ALL     = nil,
      ERROR   = { ERROR = true },
      WARN    = { WARN = true, ERROR = true },
      SUCCESS = { SUCCESS = true },
    }
    local FILTER_ORDER = { "ALL", "ERROR", "WARN", "SUCCESS" }
    local FILTER_ICON = { ALL = "◎", ERROR = "✖", WARN = "⚠", SUCCESS = "✔" }

    _G.ceb25e14eddadce3c = {}

    -- [BẢO MẬT] Che webhook / token / key trong nhật ký trước khi hiển thị, copy hoặc lưu file
    local SENSITIVE = { "key", "token", "hm", "sig", "signature", "auth", "password" }
    local function redact(s)
      s = tostring(s)
      s = s:gsub("https?://[%w%.]*discord%.com/api/webhooks/[^%s\"']+", "[webhook-hidden]")
      s = s:gsub("https?://[%w%.]*discordapp%.com/api/webhooks/[^%s\"']+", "[webhook-hidden]")
      for _, k in ipairs(SENSITIVE) do
        s = s:gsub("([%?&]" .. k .. "=)[^&%s\"']+", "%1***")
      end
      return s
    end

    local buffer = {}
    local totals = { DEBUG = 0, INFO = 0, SUCCESS = 0, WARN = 0, ERROR = 0 }
    local filterName = "ALL"
    local dirty = false

    local function fmt(e)
      local lv = LEVELS[e.level]
      local pre = lv.key and _G.tR9(lv.key) or lv.prefix
      return string.format("[%s] %s %s%s", e.stamp, pre, e.msg, e.count > 1 and (" (x" .. e.count .. ")") or "")
    end

    -- ===== GIAO DIỆN =====
    local LogGui = Instance.new("ScreenGui")
    LogGui.Name = HzN.log
    LogGui.IgnoreGuiInset = true
    LogGui.ResetOnSpawn = false
    LogGui.DisplayOrder = 100000
    LogGui.Enabled = false
    LogGui.Parent = CoreGui

    local LogFrame = Instance.new("Frame")
    LogFrame.Size = UDim2.new(0, 320, 0, 200)
    LogFrame.Position = UDim2.new(1, -330, 1, -210)
    LogFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    LogFrame.BackgroundTransparency = 0.15
    LogFrame.BorderSizePixel = 0
    LogFrame.Active = true
    LogFrame.ClipsDescendants = true
    LogFrame.Parent = LogGui
    do
      local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = LogFrame
      local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(80, 80, 80); s.Thickness = 1; s.Parent = LogFrame
    end
    if _G.HzLiquidGlass then
      _G.HzLiquidGlass(LogFrame, { radius = 16, tint = Color3.fromRGB(12, 20, 34), transparency = 0.4 })
    end

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 20)
    TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TopBar.BackgroundTransparency = (_G.HzGlassUI ~= false) and 0.6 or 0.1
    TopBar.BorderSizePixel = 0
    TopBar.Parent = LogFrame
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = TopBar end

    local TitleLog = Instance.new("TextLabel")
    TitleLog.Size = UDim2.new(1, -135, 1, 0)
    TitleLog.Position = UDim2.new(0, 5, 0, 0)
    TitleLog.BackgroundTransparency = 1
    TitleLog.Text = _G.tR9("📝 Nhật Ký")
    TitleLog.TextColor3 = Color3.fromRGB(200, 200, 200)
    TitleLog.TextSize = 12
    TitleLog.Font = Enum.Font.GothamBold
    TitleLog.TextXAlignment = Enum.TextXAlignment.Left
    TitleLog.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLog.Parent = TopBar

    local LogScroll = Instance.new("ScrollingFrame")
    LogScroll.Size = UDim2.new(1, -10, 1, -30)
    LogScroll.Position = UDim2.new(0, 5, 0, 25)
    LogScroll.BackgroundTransparency = 1
    LogScroll.BorderSizePixel = 0
    LogScroll.ScrollBarThickness = 3
    LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogScroll.Parent = LogFrame
    do
      local l = Instance.new("UIListLayout")
      l.SortOrder = Enum.SortOrder.LayoutOrder
      l.Padding = UDim.new(0, 3)
      l.Parent = LogScroll
    end

    -- ===== HIỂN THỊ (gộp theo nhịp 0.15s, tái sử dụng dòng thay vì tạo mới mỗi log) =====
    local rows = {}
    local function getRow(i)
      local r = rows[i]
      if r then return r end
      r = Instance.new("TextLabel")
      r.Size = UDim2.new(1, -4, 0, 14)
      r.BackgroundTransparency = 1
      r.TextSize = 11
      r.Font = Enum.Font.RobotoMono
      r.TextXAlignment = Enum.TextXAlignment.Left
      r.TextWrapped = true
      r.AutomaticSize = Enum.AutomaticSize.Y
      r.LayoutOrder = i
      r.Visible = false
      r.Parent = LogScroll
      rows[i] = r
      return r
    end

    local function render()
      if _G.rW15 and _G.rW15.hidden then return end -- [V35] menu ẩn → bỏ qua (dirty giữ nguyên)
      dirty = false
      local atBottom = LogScroll.CanvasPosition.Y >= (LogScroll.AbsoluteCanvasSize.Y - LogScroll.AbsoluteSize.Y - 24)
      local set = FILTERS[filterName]
      local picked = {}
      for i = #buffer, 1, -1 do
        local e = buffer[i]
        if not set or set[e.level] then
          table.insert(picked, 1, e)
          if #picked >= MAX_ROWS then break end
        end
      end
      for i = 1, math.max(#picked, #rows) do
        local e = picked[i]
        if e then
          local r = getRow(i)
          r.Text = fmt(e)
          r.TextColor3 = LEVELS[e.level].color
          r.Visible = true
        elseif rows[i] then
          rows[i].Visible = false
        end
      end
      TitleLog.Text = string.format(_G.tR9("📝 Nhật Ký  ✖%d ⚠%d ✔%d  [%s]"), totals.ERROR, totals.WARN, totals.SUCCESS, filterName)
      if atBottom then
        task.defer(function() pcall(function() LogScroll.CanvasPosition = Vector2.new(0, 99999) end) end)
      end
    end

    -- ===== GHI LOG =====
    local function forward(line, logType)
      local listeners = _G.ceb25e14eddadce3c
      if type(listeners) == "table" then
        for idx, fn in pairs(listeners) do
          local ok = pcall(fn, line, logType)
          if not ok then listeners[idx] = nil end
        end
      end
    end

    local function push(message, logType)
      logType = string.upper(tostring(logType or "INFO"))
      if not LEVELS[logType] then logType = "INFO" end
      local msg = redact(_G.tR9(message))
      local now = os.time()

      -- Gộp các dòng trùng lặp liên tiếp: "... (x3)"
      local last = buffer[#buffer]
      if last and last.msg == msg and last.level == logType and (now - last.t) <= 2 then
        last.count = last.count + 1
        last.t = now
        dirty = true
        forward(fmt(last), logType)
        return
      end

      local entry = { t = now, stamp = os.date("%H:%M:%S", now), level = logType, msg = msg, count = 1 }
      table.insert(buffer, entry)
      if #buffer > MAX_BUFFER then table.remove(buffer, 1) end
      totals[logType] = totals[logType] + 1
      dirty = true

      local line = fmt(entry)
      if logType == "ERROR" or logType == "WARN" then
        warn("[x8K2]: " .. line)
      else
        print("[x8K2]: " .. line)
      end

      forward(line, logType)
    end

    local function dumpText()
      local out = { "log | PlaceId " .. tostring(game.PlaceId) .. " | " .. os.date("%Y-%m-%d %H:%M:%S") }
      for _, e in ipairs(buffer) do table.insert(out, fmt(e)) end
      return table.concat(out, "\n")
    end

    local function saveToFile()
      if type(writefile) ~= "function" then return false, "Executor không hỗ trợ writefile" end
      local root, folder = "x8k2", "x8k2/Logs"
      pcall(function()
        if makefolder and isfolder then
          if not isfolder(root) then makefolder(root) end
          if not isfolder(folder) then makefolder(folder) end
        end
      end)
      local path = folder .. "/log_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
      local ok, err = pcall(writefile, path, dumpText())
      return ok, ok and path or tostring(err)
    end

    local function copyToClipboard()
      if type(setclipboard) ~= "function" then return false end
      return (pcall(setclipboard, dumpText()))
    end

    local function setFilter(name)
      name = string.upper(tostring(name or "ALL"))
      if name ~= "ALL" and not FILTERS[name] then name = "ALL" end
      filterName = name
      render()
    end

    local function clearLogs()
      buffer = {}
      for k in pairs(totals) do totals[k] = 0 end
      for _, r in ipairs(rows) do r.Visible = false end
      push("Đã dọn dẹp nhật ký hệ thống.", "INFO")
      render()
    end

    -- ===== NÚT ĐIỀU KHIỂN TRÊN THANH TIÊU ĐỀ =====
    local collapsed = false
    local function mkBtn(text, slot, cb)
      local b = Instance.new("TextButton")
      b.Size = UDim2.new(0, 22, 0, 16)
      b.Position = UDim2.new(1, -(slot * 25) - 24, 0, 2)
      b.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
      b.BorderSizePixel = 0
      b.Text = text
      b.TextSize = 11
      b.Font = Enum.Font.GothamBold
      b.TextColor3 = Color3.fromRGB(220, 220, 220)
      b.Parent = TopBar
      local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = b
      b.Activated:Connect(function()
        local ok, err = pcall(cb, b)
        if not ok then pcall(push, "Callback lỗi: " .. tostring(err), "ERROR") end
      end)
      return b
    end

    mkBtn("–", 0, function()
      collapsed = not collapsed
      LogScroll.Visible = not collapsed
      LogFrame.Size = collapsed and UDim2.new(0, 320, 0, 20) or UDim2.new(0, 320, 0, 200)
    end)
    mkBtn("🗑", 1, clearLogs)
    mkBtn("💾", 2, function()
      local ok, info = saveToFile()
      push(ok and ("Đã lưu nhật ký: " .. tostring(info)) or ("Lưu nhật ký thất bại: " .. tostring(info)), ok and "SUCCESS" or "ERROR")
    end)
    mkBtn("📋", 3, function()
      push(copyToClipboard() and "Đã copy nhật ký vào clipboard." or "Executor không hỗ trợ copy.", "INFO")
    end)
    local filterBtn
    filterBtn = mkBtn(FILTER_ICON.ALL, 4, function()
      local idx = table.find(FILTER_ORDER, filterName) or 1
      setFilter(FILTER_ORDER[idx % #FILTER_ORDER + 1])
      filterBtn.Text = FILTER_ICON[filterName]
    end)

    -- ===== KÉO THẢ =====
    local dragging, dragInput, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = LogFrame.Position
        input.Changed:Connect(function()
          if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
      end
    end)
    TopBar.InputChanged:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
      end
    end)
    local dragConn = UserInputService.InputChanged:Connect(function(input)
      if input == dragInput and dragging then
        local d = input.Position - dragStart
        LogFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
      end
    end)
    if type(_G._connections) ~= "table" then _G._connections = {} end
    _G._connections[dragConn] = true -- [V35]

    -- Vòng làm mới: tự dừng + ngắt kết nối khi GUI bị huỷ (không rò rỉ khi re-execute)
    task.spawn(function()
      while LogGui and LogGui.Parent do
        task.wait(FLUSH_DELAY)
        if dirty and LogGui.Enabled then pcall(render) end
      end
      pcall(function() dragConn:Disconnect() end)
    end)

    -- ===== API TOÀN CỤC (giữ tương thích bản cũ) =====
    _G.aa3542001e064bc52 = function(message, logType) pcall(push, message, logType) end
    _G.b36db0b957e59dff2 = function(val)
      pcall(function()
        LogGui.Enabled = val and true or false
        if LogGui.Enabled then render() end
      end)
    end
    _G.edf84e70ffcaf5b98 = function() pcall(clearLogs) end
    _G.fbf53b00c4ea374d7 = function() return copyToClipboard() end
    _G.a3f9b999afeefd20d = function() return saveToFile() end
    _G.fdc9d08687eec8de1 = function(name) pcall(setFilter, name) end
    _G.e864039b8f9bdcd23 = function() return dumpText() end
    _G.d5020228e3d6e626e = function()
      local lines = {}
      for _, e in ipairs(buffer) do table.insert(lines, fmt(e)) end
      return lines
    end

    pcall(function()
      if type(_G.oL16) == "function" then
        _G.oL16(function()
          if LogGui and LogGui.Parent then pcall(render) end
        end)
      end
    end)

    push("Logger sẵn sàng.", "SUCCESS")
  end)
end)

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")
local ContextActionService = game:GetService("ContextActionService")

----------------------------------------------------------------
-- HỆ THỐNG ÂM THANH & NHẠC (UPDATE PROMAX)
----------------------------------------------------------------
local CurrentMusic = nil
local CurrentVolume = 2

local function PlaySound(id, vol) -- [V35] vol tuỳ chọn
  task.spawn(function()
    pcall(function()
      local s = Instance.new("Sound")
      s.Name = HzN.sfx
      s.SoundId = "rbxassetid://" .. id
      s.Volume = vol or 1
      s.Parent = game:GetService("SoundService")
      s:Play()
      s.Ended:Connect(function() s:Destroy() end)
    end)
  end)
end

_G.HzClickSfx = function(vol) -- [V35] B7: chống spam 50ms
  local now = os.clock()
  if now - (_G.HzLastClick or 0) < 0.05 then return end
  _G.HzLastClick = now
  PlaySound("9118823103", vol or 0.3)
end

local function PlayMusic(id, name)
  pcall(function()
    if CurrentMusic then
      CurrentMusic:Stop()
      CurrentMusic:Destroy()
      CurrentMusic = nil
    end

    local s = Instance.new("Sound")
    s.Name = HzN.music
    s.SoundId = "rbxassetid://" .. id
    s.Volume = CurrentVolume
    s.Looped = true
    s.Parent = game:GetService("SoundService")
    s:Play()
    CurrentMusic = s
    _G.HzMusicRuntime = { id = tostring(id), name = tostring(name or id), volume = CurrentVolume, timePos = 0 }

    if _G.rW15 then
      pcall(function() _G.rW15:Notify({
        title = "🎶 Music Playing",
        content = _G.tR9("Đang phát: ") .. tostring(name or id),
        duration = 5,
        icon = tonumber("12623879295")
      }) end)
    end
  end)
end

-- Tạo Sound mới từ id/tên đã chụp (Sound cũ đã bị HzCleanUp dọn → không còn closure cũ nào trỏ tới Sound này).
-- Được gọi trong StartRayfield ngay sau khi dựng xong tab Nhạc: nhạc chỉ phát lại khi menu đã có nút điều khiển,
-- và TimePosition = đúng vị trí lúc re-execute (không trôi trong lúc Rayfield đang tải).
_G.HzMusicResume = function()
  local rt = _G.HzMusicRuntime
  if type(rt) ~= "table" or not rt.id or CurrentMusic then return end
  pcall(function()
    local s = Instance.new("Sound")
    s.Name = HzN.music
    s.SoundId = "rbxassetid://" .. tostring(rt.id)
    s.Volume = tonumber(rt.volume) or CurrentVolume
    s.Looped = rt.looped ~= false
    s.Parent = game:GetService("SoundService")
    CurrentVolume = s.Volume
    CurrentMusic = s
    local pos, paused, nm = tonumber(rt.timePos) or 0, rt.paused == true, tostring(rt.name or rt.id)
    task.spawn(function()
      local t0 = os.clock()
      while not s.IsLoaded and s.Parent and os.clock() - t0 < 5 do task.wait() end
      if not s.Parent then return end -- bị huỷ trong lúc chờ tải (vd. Đóng menu)
      pcall(function()
        if s.TimeLength > 0 then pos = math.clamp(pos, 0, math.max(0, s.TimeLength - 0.05)) end
        s.TimePosition = pos
        s:Play()
        if paused then s:Pause() end -- đang tạm dừng trước re-execute → giữ nguyên tạm dừng
        if _G.aa3542001e064bc52 then
          _G.aa3542001e064bc52("Music: resumed " .. nm .. " @ " .. string.format("%.1f", pos) .. "s", "INFO")
        end
      end)
    end)
  end)
end

-- để autoLoad không restore bài/âm lượng cũ nữa. Chỉ xoá đúng các key nhạc; key khác giữ nguyên.
_G.HzMusicSanitize = function()
  if type(isfile) ~= "function" or type(readfile) ~= "function" or type(writefile) ~= "function" then return end
  local HttpService = game:GetService("HttpService")
  local function isMusicKey(k)
    if type(k) ~= "string" then return false end
    return k == "MusicPlaylistDropdown" or k:lower():sub(1, 7) == "__music"
      or k == "Âm lượng" or k == "Volume" -- slider âm lượng cũ (không có Flag; tuỳ bản Rayfield lưu theo tên)
  end
  local function strip(t, depth)
    if type(t) ~= "table" or depth > 4 then return 0 end
    local n = 0
    for k, v in pairs(t) do
      if isMusicKey(k) then
        t[k] = nil
        n = n + 1
      elseif type(v) == "table" then
        n = n + strip(v, depth + 1)
      end
    end
    return n
  end
  for _, path in ipairs({ "x8k2/Main.json", "x8k2/Main.rfld" }) do
    pcall(function()
      if not isfile(path) then return end
      local data = HttpService:JSONDecode(readfile(path))
      local n = strip(data, 0)
      if n > 0 then
        writefile(path, HttpService:JSONEncode(data))
        if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Music: đã xoá " .. n .. " key nhạc cũ khỏi " .. path, "INFO") end
      end
    end)
  end
end
pcall(_G.HzMusicSanitize)

----------------------------------------------------------------
-- HỆ THỐNG GUI AN TOÀN
----------------------------------------------------------------
local function GetSafeGui()
  local success, core = pcall(function()
    return game:GetService("CoreGui")
  end)
  if success and core then
    return core
  end

  local Players = game:GetService("Players")
  local lp = Players.LocalPlayer
  if lp then
    return lp:WaitForChild("PlayerGui")
  end

  return game:GetService("CoreGui")
end

local ScreenParent = GetSafeGui()

-- [V35] B1: Toast pool (không thay Notify)
do
  local TweenService = game:GetService("TweenService")
  local COLORS = { info = Color3.fromRGB(90,170,255), success = Color3.fromRGB(80,220,120),
    warn = Color3.fromRGB(255,190,60), error = Color3.fromRGB(255,90,90), music = Color3.fromRGB(190,120,255) }
  local ICONS = { info = "●", success = "✓", warn = "⚠", error = "✕", music = "♪" }
  local POOL, MAXSHOW, W, H, GAP = 5, 3, 260, 56, 8
  local gui, slots, active = nil, {}, {} -- active[1] = mới nhất (trên cùng)

  local function ensure()
    if gui and gui.Parent then return true end
    local ok = pcall(function()
      gui = Instance.new("ScreenGui")
      gui.Name = HzN.toast; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 10050
      gui.Parent = ScreenParent
      slots, active = {}, {}
      for i = 1, POOL do
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, W, 0, H); f.AnchorPoint = Vector2.new(1, 0)
        f.Position = UDim2.new(1, W + 20, 0, 12); f.Visible = false
        f.BackgroundColor3 = Color3.fromRGB(22, 24, 34); f.BackgroundTransparency = 0.08; f.BorderSizePixel = 0
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = f
        local st = Instance.new("UIStroke"); st.Thickness = 1.2; st.Transparency = 0.6; st.Parent = f
        local ic = Instance.new("TextLabel"); ic.Size = UDim2.new(0, 30, 1, 0); ic.Position = UDim2.new(0, 4, 0, 0)
        ic.BackgroundTransparency = 1; ic.Font = Enum.Font.GothamBold; ic.TextSize = 20; ic.Parent = f
        local tt = Instance.new("TextLabel"); tt.Size = UDim2.new(1, -44, 0, 20); tt.Position = UDim2.new(0, 38, 0, 8)
        tt.BackgroundTransparency = 1; tt.Font = Enum.Font.GothamBold; tt.TextSize = 13; tt.TextColor3 = Color3.new(1, 1, 1)
        tt.TextXAlignment = Enum.TextXAlignment.Left; tt.TextTruncate = Enum.TextTruncate.AtEnd; tt.Parent = f
        local mm = Instance.new("TextLabel"); mm.Size = UDim2.new(1, -44, 0, 18); mm.Position = UDim2.new(0, 38, 0, 28)
        mm.BackgroundTransparency = 1; mm.Font = Enum.Font.Gotham; mm.TextSize = 11; mm.TextColor3 = Color3.fromRGB(190, 195, 210)
        mm.TextXAlignment = Enum.TextXAlignment.Left; mm.TextTruncate = Enum.TextTruncate.AtEnd; mm.Parent = f
        f.Parent = gui
        slots[i] = { frame = f, stroke = st, icon = ic, title = tt, msg = mm, token = 0, busy = false }
      end
    end)
    return ok and gui ~= nil
  end

  local function yOf(i) return 12 + (i - 1) * (H + GAP) end
  local function layout()
    for i, s in ipairs(active) do
      pcall(function()
        TweenService:Create(s.frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = UDim2.new(1, -12, 0, yOf(i)) }):Play()
      end)
    end
  end
  local function release(s)
    local idx = table.find(active, s); if idx then table.remove(active, idx) end
    s.token = s.token + 1
    local tok = s.token
    pcall(function()
      TweenService:Create(s.frame, TweenInfo.new(0.25), { Position = UDim2.new(1, W + 20, 0, s.frame.Position.Y.Offset), BackgroundTransparency = 1 }):Play()
    end)
    task.delay(0.3, function() if s.token == tok then s.frame.Visible = false; s.busy = false end end)
    layout()
  end

  _G.HzToast = function(level, title, msg, duration)
    pcall(function()
      if not ensure() then return end
      level = COLORS[level] and level or "info"
      duration = tonumber(duration) or 3
      if #active >= MAXSHOW then release(active[#active]) end -- đẩy toast cũ nhất ra
      local s
      for _, x in ipairs(slots) do if not x.busy then s = x break end end
      if not s then for _, x in ipairs(slots) do if not table.find(active, x) then s = x break end end end -- đang fade → tái dùng
      if not s then s = active[#active]; if s then release(s) end end
      if not s then return end
      s.token = s.token + 1; s.busy = true
      local tok = s.token
      local tr = type(_G.tR9) == "function" and _G.tR9 or function(x) return x end
      s.icon.Text, s.icon.TextColor3 = ICONS[level], COLORS[level]
      s.stroke.Color = COLORS[level]
      s.title.Text, s.msg.Text = tr(tostring(title or "")), tr(tostring(msg or ""))
      s.frame.BackgroundTransparency = 0.08
      s.frame.Position = UDim2.new(1, W + 20, 0, yOf(1))
      s.frame.Visible = true
      table.insert(active, 1, s)
      layout()
      if _G.HzClickSfx then _G.HzClickSfx(0.4) end
      task.delay(duration, function() if s.token == tok then release(s) end end)
    end)
  end
end

local AFKGui = Instance.new("ScreenGui")
AFKGui.Name = HzN.afk .. math.random(100, 999)
AFKGui.IgnoreGuiInset = true
AFKGui.ResetOnSpawn = false -- [FIX] Chống mất UI khi chết
AFKGui.DisplayOrder = 5
AFKGui.Parent = ScreenParent

local AFKFrame = Instance.new("Frame")
AFKFrame.Size = UDim2.new(1, 0, 1, 0)
AFKFrame.Visible = false
AFKFrame.BorderSizePixel = 0
AFKFrame.ZIndex = 1
AFKFrame.Parent = AFKGui

----------------------------------------------------------------
-- 1. HỆ THỐNG LOADING GALAXY STYLE (FIXED)
----------------------------------------------------------------
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = HzN.loading -- giữ nguyên: phần dọn GUI cũ so khớp theo tên này
LoadingGui.IgnoreGuiInset = true
LoadingGui.ResetOnSpawn = false -- [FIX] Chống mất UI khi chết
LoadingGui.DisplayOrder = 10000
LoadingGui.Parent = ScreenParent

-- Các biến dùng ở ngoài khối này (RunLoading ở cuối file)
local BarFill, StatusText, SetLoadProgress, CloseLoading

do
  local gui = LoadingGui
  local TI = TweenInfo.new
  local EStyle, EDir = Enum.EasingStyle, Enum.EasingDirection

  local function tween(obj, info, props)
    local ok, t = pcall(function() return TweenService:Create(obj, info, props) end)
    if ok and t then t:Play() return t end
  end
  local function alive() return gui.Parent ~= nil end
  local function round(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r
    c.Parent = inst
    return c
  end

  -- Tự co theo màn hình nhỏ (điện thoại)
  local baseScale = 1
  pcall(function()
    local vp = workspace.CurrentCamera.ViewportSize
    local uis = game:GetService("UserInputService")
    local maxScale = (uis.KeyboardEnabled and uis.MouseEnabled) and 1.4 or 1
    baseScale = math.clamp(math.min(vp.X / 440, vp.Y / 300), 0.55, maxScale)
  end)

  -- [V26 LITE] Loading nhẹ cho máy yếu. Tự bật khi: máy cảm ứng không bàn phím / đồ hoạ thấp / FPS thực < 40.
  -- Ép tay (đặt TRƯỚC khi chạy script): getgenv().HzLiteLoading = true (luôn nhẹ) / false (luôn đầy đủ hiệu ứng)
  local LITE = false
  -- [PERF] dùng chung _G.HzDetectPerfLevel() (đã cache) thay vì đo lại; LITE = LOW.
  -- MED/HIGH tra bằng _G.HzPerfLvl để khỏi thêm biến local (giới hạn 200).
  pcall(function() LITE = (_G.HzDetectPerfLevel() == "low") end)
  _G.HzLiteLoad = LITE

  -- Nền mờ (giữ tên "Overlay": code cuối StartRayfield còn tham chiếu)
  local Overlay = Instance.new("Frame")
  Overlay.Name = "Overlay"
  Overlay.Size = UDim2.new(1, 0, 1, 0)
  Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
  Overlay.BackgroundTransparency = 1
  Overlay.BorderSizePixel = 0
  Overlay.Parent = gui
  tween(Overlay, TI(0.5), {BackgroundTransparency = 0.4})

  -- Sao bay lơ lửng
  local Stars = Instance.new("Frame")
  Stars.Name = "Stars"
  Stars.Size = UDim2.new(1, 0, 1, 0)
  Stars.BackgroundTransparency = 1
  Stars.Parent = gui
  for _ = 1, (LITE and 0 or (_G.HzPerfLvl == "med" and 6 or 12)) do -- [PERF] HIGH 12 | MED 6 | LOW 0
    local s = Instance.new("Frame")
    local sz = math.random(2, 4)
    s.Size = UDim2.new(0, sz, 0, sz)
    s.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    s.BackgroundTransparency = math.random(30, 60) / 100
    s.BorderSizePixel = 0
    s.Position = UDim2.new(math.random(), 0, math.random(), 0)
    round(s, UDim.new(1, 0))
    s.Parent = Stars
    task.spawn(function()
      local first = true
      while alive() do
        local x = math.random()
        local y0 = first and s.Position.Y.Scale or 1.02
        local dur = math.random(50, 100) / 10 * ((y0 + 0.05) / 1.07)
        first = false
        s.Position = UDim2.new(x, 0, y0, 0)
        tween(s, TI(dur, EStyle.Linear), {Position = UDim2.new(x, 0, -0.05, 0)})
        task.wait(dur)
      end
    end)
  end

  -- Khung chứa (hiệu ứng bật ra / thu vào)
  local Holder = Instance.new("Frame")
  Holder.Name = "Holder"
  Holder.AnchorPoint = Vector2.new(0.5, 0.5)
  Holder.Position = UDim2.new(0.5, 0, 0.5, 0)
  Holder.Size = UDim2.new(0, 404, 0, 244)
  Holder.BackgroundTransparency = 1
  Holder.Parent = gui

  local Scale = Instance.new("UIScale")
  Scale.Scale = baseScale * 0.8
  Scale.Parent = Holder
  tween(Scale, TI(0.55, EStyle.Back, EDir.Out), {Scale = baseScale})

  local GlowFrame = Instance.new("Frame")
  GlowFrame.Name = "GlowFrame"
  GlowFrame.Size = UDim2.new(1, 0, 1, 0)
  GlowFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  GlowFrame.BackgroundTransparency = 0.82
  GlowFrame.BorderSizePixel = 0
  round(GlowFrame, UDim.new(0, 18))
  GlowFrame.Parent = Holder
  if not LITE then tween(GlowFrame, TI(1.1, EStyle.Sine, EDir.InOut, -1, true), {BackgroundTransparency = 0.93}) end

  -- Thẻ chính: dùng CanvasGroup để fade mượt khi đóng (fallback: Frame thường)
  local MainFrame
  do
    local ok, cg = pcall(Instance.new, "CanvasGroup")
    MainFrame = (not LITE and ok and cg) or Instance.new("Frame")
  end
  local isCG = MainFrame:IsA("CanvasGroup")
  MainFrame.Name = "MainFrame"
  MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
  MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
  MainFrame.Size = UDim2.new(0, 380, 0, 220)
  MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
  MainFrame.BorderSizePixel = 0
  MainFrame.ClipsDescendants = true
  round(MainFrame, UDim.new(0, 14))
  MainFrame.Parent = Holder
  if _G.HzLiquidGlass and _G.HzGlassUI ~= false then
    _G.HzLiquidGlass(MainFrame, { stroke = false, glossZ = 2, blur = true, blurSize = 12, blurTime = 20 })
  end

  local UniverseBg = Instance.new("ImageLabel")
  UniverseBg.Name = "UniverseBackground" -- giữ tên: low-mode tìm theo tên này
  UniverseBg.Size = UDim2.new(1, 0, 1, 0)
  UniverseBg.BackgroundTransparency = 1
  UniverseBg.Image = "rbxassetid://5323900286"
  UniverseBg.ScaleType = Enum.ScaleType.Crop
  UniverseBg.ImageTransparency = (_G.HzGlassUI ~= false and not LITE) and 0.45 or 0.1
  UniverseBg.ZIndex = 1
  UniverseBg.Parent = MainFrame

  local Shade = Instance.new("Frame")
  Shade.Size = UDim2.new(1, 0, 1, 0)
  Shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
  Shade.BorderSizePixel = 0
  Shade.ZIndex = 2
  Shade.Parent = MainFrame
  if LITE then round(Shade, UDim.new(0, 14)) end
  local ShadeGrad = Instance.new("UIGradient")
  ShadeGrad.Rotation = 90
  ShadeGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, (_G.HzGlassUI ~= false and not LITE) and 0.72 or 0.55),
    NumberSequenceKeypoint.new(1, (_G.HzGlassUI ~= false and not LITE) and 0.4 or 0.2),
  })
  ShadeGrad.Parent = Shade

  -- Viền cầu vồng xoay (đặt ngoài CanvasGroup để không bị cắt)
  local Border = Instance.new("Frame")
  Border.Name = "Border"
  Border.AnchorPoint = Vector2.new(0.5, 0.5)
  Border.Position = UDim2.new(0.5, 0, 0.5, 0)
  Border.Size = UDim2.new(0, 380, 0, 220)
  Border.BackgroundTransparency = 1
  Border.ZIndex = 5
  round(Border, UDim.new(0, 14))
  Border.Parent = Holder
  local UIStroke = Instance.new("UIStroke")
  UIStroke.Thickness = 3
  UIStroke.Color = Color3.fromRGB(255, 255, 255)
  UIStroke.Parent = Border
  local StrokeGrad = Instance.new("UIGradient")
  StrokeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 70, 70)),
    ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255, 220, 80)),
    ColorSequenceKeypoint.new(0.40, Color3.fromRGB(80, 255, 140)),
    ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0, 230, 255)),
    ColorSequenceKeypoint.new(0.80, Color3.fromRGB(170, 100, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 70, 70)),
  })
  StrokeGrad.Parent = UIStroke
  if not LITE then tween(StrokeGrad, TI(3.5, EStyle.Linear, EDir.Out, -1), {Rotation = 360}) end

  -- Tiêu đề
  local TitleLoad = Instance.new("TextLabel")
  TitleLoad.Size = UDim2.new(1, 0, 0, 52)
  TitleLoad.Position = UDim2.new(0, 0, 0, 34)
  TitleLoad.Text = "HiulzHub"
  TitleLoad.TextColor3 = Color3.fromRGB(255, 255, 255)
  TitleLoad.TextSize = 34
  TitleLoad.Font = Enum.Font.GothamBold
  TitleLoad.BackgroundTransparency = 1
  TitleLoad.TextTransparency = 1
  TitleLoad.ZIndex = 3
  TitleLoad.Parent = MainFrame
  tween(TitleLoad, TI(0.6, EStyle.Quart, EDir.Out), {TextTransparency = 0, Position = UDim2.new(0, 0, 0, 26)})

  -- Logo
  local LogoImg = Instance.new("ImageLabel")
  LogoImg.Size = UDim2.new(0, 46, 0, 46)
  LogoImg.Position = UDim2.new(0.5, -140, 0, 30)
  LogoImg.BackgroundTransparency = 1
  LogoImg.Image = "rbxassetid://131699875210935"
  LogoImg.ImageTransparency = 1
  LogoImg.ZIndex = 3
  LogoImg.Parent = MainFrame
  round(LogoImg, UDim.new(0, 10))
  tween(LogoImg, TI(0.6, EStyle.Quart, EDir.Out), {ImageTransparency = 0, Position = UDim2.new(0.5, -140, 0, 24)})

  local TitleGlow = Instance.new("UIStroke")
  TitleGlow.Thickness = 2
  TitleGlow.Color = Color3.fromRGB(255, 0, 0)
  TitleGlow.Transparency = 0.5
  TitleGlow.Parent = TitleLoad

  local TitleGradient = Instance.new("UIGradient")
  TitleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255)),
  })
  TitleGradient.Parent = TitleLoad
  if not LITE then tween(TitleGradient, TI(1.6, EStyle.Sine, EDir.InOut, -1, true), {Offset = Vector2.new(0.35, 0)}) end

  -- Lời chào
  local Greeting = Instance.new("TextLabel")
  Greeting.Size = UDim2.new(1, 0, 0, 18)
  Greeting.Position = UDim2.new(0, 0, 0, 82)
  Greeting.BackgroundTransparency = 1
  Greeting.Font = Enum.Font.GothamMedium
  Greeting.TextSize = 13
  Greeting.TextColor3 = Color3.fromRGB(190, 215, 255)
  Greeting.ZIndex = 3
  Greeting.Parent = MainFrame
  local who = _G.tR9("bạn")
  Greeting.Text = _G.tR9("Xin chào, ") .. who .. " 👋"

  -- Thanh tiến trình + % + shimmer
  local PercentLabel = Instance.new("TextLabel")
  PercentLabel.Size = UDim2.new(0, 300, 0, 16)
  PercentLabel.Position = UDim2.new(0.5, -150, 0, 124)
  PercentLabel.BackgroundTransparency = 1
  PercentLabel.Font = Enum.Font.GothamBold
  PercentLabel.TextSize = 12
  PercentLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
  PercentLabel.TextXAlignment = Enum.TextXAlignment.Right
  PercentLabel.Text = "0%"
  PercentLabel.ZIndex = 3
  PercentLabel.Parent = MainFrame

  local BarBack = Instance.new("Frame")
  BarBack.Size = UDim2.new(0, 300, 0, 8)
  BarBack.Position = UDim2.new(0.5, -150, 0, 144)
  BarBack.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
  BarBack.BorderSizePixel = 0
  BarBack.ZIndex = 3
  round(BarBack, UDim.new(1, 0))
  BarBack.Parent = MainFrame

  BarFill = Instance.new("Frame")
  BarFill.Size = UDim2.new(0, 0, 1, 0)
  BarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  BarFill.BorderSizePixel = 0
  BarFill.ClipsDescendants = true
  BarFill.ZIndex = 4
  round(BarFill, UDim.new(1, 0))
  BarFill.Parent = BarBack
  local FillGradient = Instance.new("UIGradient")
  FillGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 255)),
  })
  FillGradient.Parent = BarFill

  local Shine = Instance.new("Frame")
  Shine.Size = UDim2.new(1, 0, 1, 0)
  Shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  Shine.BorderSizePixel = 0
  Shine.ZIndex = 5
  Shine.Parent = BarFill
  local ShineGrad = Instance.new("UIGradient")
  ShineGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 0.35),
    NumberSequenceKeypoint.new(1, 1),
  })
  ShineGrad.Offset = Vector2.new(-1, 0)
  ShineGrad.Parent = Shine
  if not LITE and _G.HzPerfLvl ~= "med" then tween(ShineGrad, TI(1.2, EStyle.Linear, EDir.Out, -1), {Offset = Vector2.new(1, 0)}) end -- [PERF] shimmer chỉ HIGH

  -- Trạng thái + mẹo
  StatusText = Instance.new("TextLabel")
  StatusText.Size = UDim2.new(1, 0, 0, 18)
  StatusText.Position = UDim2.new(0, 0, 0, 160)
  StatusText.Text = _G.tR9("Khởi động...")
  StatusText.TextColor3 = Color3.fromRGB(255, 255, 255)
  StatusText.TextSize = 12
  StatusText.Font = Enum.Font.GothamMedium
  StatusText.BackgroundTransparency = 1
  StatusText.ZIndex = 3
  StatusText.Parent = MainFrame

  -- [V35] B3: 6 chấm step (hiện cả ở LITE)
  local stepDots = {}
  do
    local row = Instance.new("Frame")
    row.Name = "Steps"; row.BackgroundTransparency = 1
    row.AnchorPoint = Vector2.new(0.5, 0)
    row.Position = UDim2.new(0.5, 0, 0, 180)
    row.Size = UDim2.new(0, 6 * 6 + 5 * 12, 0, 6)
    row.ZIndex = 3; row.Parent = MainFrame
    for i = 1, 6 do
      local d = Instance.new("Frame")
      d.Size = UDim2.new(0, 6, 0, 6)
      d.Position = UDim2.new(0, (i - 1) * 18, 0, 0)
      d.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
      d.BorderSizePixel = 0; d.ZIndex = 3
      round(d, UDim.new(1, 0))
      d.Parent = row
      stepDots[i] = d
    end
  end

  local TipLabel = Instance.new("TextLabel")
  TipLabel.Size = UDim2.new(1, -20, 0, 16)
  TipLabel.Position = UDim2.new(0, 10, 0, 190)
  TipLabel.BackgroundTransparency = 1
  TipLabel.Font = Enum.Font.Gotham
  TipLabel.TextSize = 11
  TipLabel.TextColor3 = Color3.fromRGB(170, 180, 200)
  TipLabel.TextTransparency = 1
  TipLabel.Text = ""
  TipLabel.ZIndex = 3
  TipLabel.Parent = MainFrame

  if not LITE then
    local SkipBtn = Instance.new("TextButton")
    SkipBtn.Name = "SkipBtn"
    SkipBtn.AnchorPoint = Vector2.new(1, 0)
    SkipBtn.Position = UDim2.new(1, -12, 0, 12)
    SkipBtn.Size = UDim2.new(0, 78, 0, 26)
    SkipBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SkipBtn.BackgroundTransparency = 0.88
    SkipBtn.BorderSizePixel = 0
    SkipBtn.AutoButtonColor = true
    SkipBtn.Font = Enum.Font.GothamMedium
    SkipBtn.TextSize = 12
    SkipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SkipBtn.Text = _G.tR9("Bỏ qua »")
    SkipBtn.ZIndex = 10
    round(SkipBtn, UDim.new(0, 8))
    SkipBtn.Parent = MainFrame
    SkipBtn.Activated:Connect(function()
      if gui:GetAttribute("Skip") then return end
      gui:SetAttribute("Skip", true)
      SkipBtn.AutoButtonColor = false
      SkipBtn.Text = _G.tR9("Đang bỏ qua...")
    end)
  end

  local tips = {
    "💡 Menu tự nhận diện game.",
    "💡 Tab Khác chạy được ở mọi game.",
    "💡 Tab Nhạc để nghe khi chơi.",
  }
  task.spawn(function()
    local i = 1
    while alive() do
      TipLabel.Text = _G.tR9(tips[i])
      TipLabel.TextTransparency = 1
      tween(TipLabel, TI(0.3), {TextTransparency = 0.15})
      task.wait(1.4)
      i = i % #tips + 1
    end
  end)

  -- Cập nhật tiến trình (thanh + % + chữ trạng thái)
  local pv = Instance.new("NumberValue")
  pv.Value = 0
  pv.Changed:Connect(function(v)
    if alive() then PercentLabel.Text = string.format("%d%%", math.floor(v * 100 + 0.5)) end
  end)

  SetLoadProgress = function(frac, text)
    if not alive() then return end
    tween(BarFill, TI(0.8, EStyle.Quart, EDir.Out), {Size = UDim2.new(frac, 0, 1, 0)})
    tween(pv, TI(0.8, EStyle.Quart, EDir.Out), {Value = frac})
    if text then
      StatusText.Text = _G.tR9(text)
      StatusText.TextTransparency = 0.7
      tween(StatusText, TI(0.3), {TextTransparency = 0})
    end
    local stepNow = math.floor((frac or 0) * 6) -- [V35]
    for i, d in ipairs(stepDots) do
      tween(d, TI(0.25), { BackgroundColor3 = (i <= stepNow) and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(60, 60, 80) })
    end
  end

  -- Đóng loading: thu nhỏ + mờ dần rồi mới huỷ
  CloseLoading = function()
    if not alive() then return end
    task.spawn(function()
      tween(Overlay, TI(0.35), {BackgroundTransparency = 1})
      tween(Scale, TI(0.35, EStyle.Back, EDir.In), {Scale = baseScale * 0.9})
      if GlowFrame then tween(GlowFrame, TI(0.35), {BackgroundTransparency = 1}) end
      tween(UIStroke, TI(0.35), {Transparency = 1})
      if isCG then tween(MainFrame, TI(0.35), {GroupTransparency = 1}) end
      for _, s in ipairs(Stars:GetChildren()) do
        tween(s, TI(0.3), {BackgroundTransparency = 1})
      end
      task.wait(0.4)
      pcall(function() gui:Destroy() end)
      pcall(function() pv:Destroy() end)
    end)
  end

  -- Vòng lặp màu cầu vồng cho glow + viền chữ (bỏ khi LITE; 10 lần/giây thay vì 20)
  if not LITE then
    task.spawn(function()
      while alive() do
        local t = tick()
        local rainbow = Color3.fromHSV((t % 5) / 5, 0.8, 1)
        GlowFrame.BackgroundColor3 = rainbow
        TitleGlow.Color = rainbow
        task.wait(0.1)
      end
    end)
  end
end

if _G.HzPerf then _G.HzPerf("Loading dựng xong") end

----------------------------------------------------------------
-- HIULZ FRAMEWORK: Module + Orchestrator (một vòng tick trung tâm)
----------------------------------------------------------------
local HiulzFW = (function()
pcall(function() if _G.hZ3nB2 and _G.hZ3nB2.Shutdown then _G.hZ3nB2.Shutdown() end end)
local Framework = {}

----------------------------------------------------------------
-- Core: cache service
----------------------------------------------------------------
local Services = setmetatable({}, {
  __index = function(t, name)
    local ok, s = pcall(game.GetService, game, name)
    if not ok or not s then return nil end
    rawset(t, name, s)
    return s
  end,
})

----------------------------------------------------------------
-- Core: Config (lưu file, ghi gộp mỗi vài giây)
----------------------------------------------------------------
local Config = { _data = {}, _dir = "x8k2", _file = "x8k2/framework.json", _dirty = false }

function Config:Load()
  pcall(function()
    if type(isfile) == "function" and type(readfile) == "function" and isfile(self._file) then
      local d = Services.HttpService:JSONDecode(readfile(self._file))
      if type(d) == "table" then self._data = d end
    end
  end)
end

function Config:Get(key, default)
  local v = self._data[key]
  if v == nil then return default end
  return v
end

function Config:Set(key, value)
  self._data[key] = value
  self._dirty = true
end

function Config:Flush()
  if not self._dirty or type(writefile) ~= "function" then return end
  pcall(function()
    if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(self._dir) then
      makefolder(self._dir)
    end
    writefile(self._file, Services.HttpService:JSONEncode(self._data))
    self._dirty = false
  end)
end

----------------------------------------------------------------
-- Core: Bus (sự kiện giữa các module, module không gọi trực tiếp nhau)
----------------------------------------------------------------
local Bus = { _handlers = {} }

function Bus:On(event, fn)
  local list = self._handlers[event]
  if not list then list = {} self._handlers[event] = list end
  table.insert(list, fn)
  return function() -- gọi hàm này để huỷ đăng ký
    local i = table.find(list, fn)
    if i then table.remove(list, i) end
  end
end

function Bus:Emit(event, ...)
  local list = self._handlers[event]
  if not list then return end
  for _, fn in ipairs({ table.unpack(list) }) do
    local ok, err = pcall(fn, ...)
    if not ok then warn("[x8K2] Bus handler error (" .. tostring(event) .. "): " .. tostring(err)) end
  end
end

----------------------------------------------------------------
-- Orchestrator
----------------------------------------------------------------
local Orchestrator = { modules = {}, order = {}, conn = nil, running = false, MAX_ERRORS = 5 }

local function safe(mod, fn, ...)
  if type(fn) ~= "function" then return true end
  local ok, err = pcall(fn, mod, ...)
  if ok then
    mod._errors = 0
    return true
  end
  mod._errors = (mod._errors or 0) + 1
  warn(string.format("[x8K2] Module %s error (%d/%d): %s", mod.Name, mod._errors, Orchestrator.MAX_ERRORS, tostring(err)))
  Bus:Emit("module:error", mod.Name, err)
  if mod._errors >= Orchestrator.MAX_ERRORS and mod.Enabled then
    mod.Enabled = false -- tự tắt module hỏng, không kéo cả menu chết theo
    Orchestrator:_disable(mod)
    Bus:Emit("module:toggled", mod.Name, false)
  end
  return false
end

function Orchestrator:Register(name, def)
  assert(type(name) == "string" and type(def) == "table", "Register(name, table)")
  assert(not self.modules[name], "Duplicate module name: " .. name)
  def.Name = name
  def.BaseInterval = tonumber(def.Interval) or 0.5 -- [PERF] giữ giá trị gốc
  def.Interval = def.BaseInterval * _G.HzPerfPick(1, 1.5, 2) -- [PERF] HIGH ×1 | MED ×1.5 | LOW ×2 (0 = mỗi khung giữ nguyên)
  def.Priority = tonumber(def.Priority) or 100
  def._acc, def._errors = 0, 0
  if def.Persist == false then
    def.Enabled = (def.Enabled == true)
  else
    def.Enabled = Config:Get("mod." .. name, def.Enabled ~= false)
  end
  self.modules[name] = def
  table.insert(self.order, def)
  table.sort(self.order, function(a, b) return a.Priority < b.Priority end)
  return def
end

function Orchestrator:Get(name)
  return self.modules[name]
end

function Orchestrator:_enable(m)
  if m._on then return end
  m._on = true
  safe(m, m.OnEnable)
end

function Orchestrator:_disable(m)
  if not m._on then return end
  m._on = false
  safe(m, m.OnDisable)
end

function Orchestrator:SetEnabled(name, on)
  local m = self.modules[name]
  if not m or m.Enabled == on then return end
  m.Enabled, m._errors = on, 0
  if m.Persist ~= false then Config:Set("mod." .. name, on) end
  if on then self:_enable(m) else self:_disable(m) end
  Bus:Emit("module:toggled", name, on)
end

function Orchestrator:Start()
  if self.running then return end
  self.running = true
  for _, m in ipairs(self.order) do
    safe(m, m.Init)
    if m.Enabled then self:_enable(m) end
  end
  local flushAcc = 0
  self.conn = Services.RunService.Heartbeat:Connect(function(dt)
    for _, m in ipairs(self.order) do
      if m.Enabled and m.Tick then
        m._acc = m._acc + dt
        if m._acc >= m.Interval then
          local elapsed = m._acc
          m._acc = 0
          safe(m, m.Tick, elapsed)
        end
      end
    end
    flushAcc = flushAcc + dt
    if flushAcc >= 5 then
      flushAcc = 0
      Config:Flush()
    end
  end)
end

function Orchestrator:Shutdown()
  if not self.running then return end
  self.running = false
  if self.conn then self.conn:Disconnect() self.conn = nil end
  for i = #self.order, 1, -1 do
    local m = self.order[i]
    self:_disable(m)
    safe(m, m.Destroy)
  end
  Config:Flush()
  Bus:Emit("framework:shutdown")
end

----------------------------------------------------------------
-- UI Builder
----------------------------------------------------------------
local UI = {}

function UI.SetLabel(handle, text)
  if type(handle) ~= "table" then return end
  pcall(function()
    if handle.Set then handle:Set(text) elseif handle.SetText then handle:SetText(text) end
  end)
end

-- Tạo công tắc bật/tắt cho các module cho phép tắt (Toggleable ~= false)
function UI.AddModuleToggles(tab)
  tab:CreateSection("Module")
  for _, m in ipairs(Orchestrator.order) do
    if m.Toggleable ~= false then
      tab:CreateToggle({
        Name = m.Title or m.Name,
        CurrentValue = m.Enabled,
        Callback = function(v) Orchestrator:SetEnabled(m.Name, v) end,
      })
    end
  end
end

Config:Load()

----------------------------------------------------------------
-- API công khai
----------------------------------------------------------------
Framework.Services = Services
Framework.Config = Config
Framework.Bus = Bus
Framework.Orchestrator = Orchestrator
Framework.UI = UI

function Framework.Register(name, def) return Orchestrator:Register(name, def) end

function Framework.Start()
  Orchestrator:Start()
end

function Framework.Shutdown() Orchestrator:Shutdown() end

_G.hZ3nB2 = Framework
return Framework
end)()

pcall(function() _G.HzCfg = HiulzFW.Config end)

----------------------------------------------------------------
----------------------------------------------------------------
-- _G.HzDetectGame(placeId, universeId, gameName) -> table cờ boolean:
--   isJumpShowdown, isJJS, isTSB, isBloxFruit, isEscapeTsunami, isTitanFishing, isFishIt, isFish, isMM2,
--   isGardenHorizons, isEvadeGame, isDoors, is99Nights, isKnockout, isStealAnEgg, isKingLegacy, any
-- Tham số không bắt buộc (thiếu thì lấy từ game.PlaceId / game.GameId / MarketplaceService).
_G.HzFetchGameName = function(placeId, timeout, onLate)
  local result, done, gaveUp = nil, false, false
  local pid = tonumber(placeId) or 0
  if pid == 0 then pcall(function() pid = tonumber(game.PlaceId) or 0 end) end
  local okSp = pcall(task.spawn, function()
    local ok, info = pcall(function()
      return game:GetService("MarketplaceService"):GetProductInfo(pid)
    end)
    if ok and type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
      result = info.Name
    end
    done = true
    if gaveUp and result and type(onLate) == "function" then pcall(onLate, result) end
  end)
  if okSp then
    local t0, limit = os.clock(), tonumber(timeout) or 3
    while not done and (os.clock() - t0) < limit do task.wait(0.05) end
    if not done then gaveUp = true end
  end
  if not result then
    pcall(function()
      if type(game.Name) == "string" and game.Name ~= "" then result = game.Name end
    end)
  end
  return result or "Unknown"
end

_G.HzDetectGame = (function()
  local FLAGS = {
    "isJumpShowdown", "isJJS", "isTSB", "isBloxFruit", "isEscapeTsunami", "isTitanFishing",
    "isFishIt", "isFish", "isMM2", "isGardenHorizons", "isEvadeGame", "isDoors",
    "is99Nights", "isKnockout", "isStealAnEgg", "isKingLegacy",
  }
  local DEFAULT_PLACES = {
    ["18519254033"] = "isJumpShowdown",
    ["10450270085"] = "isJJS",
    ["10449761463"] = "isTSB",
    ["2753915549"] = "isBloxFruit", ["4442272183"] = "isBloxFruit", ["7449423635"] = "isBloxFruit",
    ["131623223084840"] = "isEscapeTsunami",
    ["115893378298440"] = "isTitanFishing",
    ["121864768012064"] = "isFishIt",
    ["16732694052"] = "isFish",
    ["142823291"] = "isMM2",
    ["9872472334"] = "isEvadeGame",
    ["6516141723"] = "isDoors", ["6839171747"] = "isDoors",
    ["79546208627805"] = "is99Nights",
    ["16008852324"] = "isKnockout",
    ["107778070777162"] = "isStealAnEgg",
    ["4520749081"] = "isKingLegacy", ["6381829480"] = "isKingLegacy", ["15759515082"] = "isKingLegacy",
  }
  local DEFAULT_UNIVERSES = {
    ["3760416955"] = "isJJS",
    ["3751717616"] = "isTSB",
    ["994732206"] = "isBloxFruit",
    ["10563114921"] = "isStealAnEgg",
  }

  -- [V35] C1: overlay từ scripts.json (keys: places, universes) + cache đĩa TTL 7 ngày
  local PLACES_FILE, PLACES_TTL = "x8k2/places_cache.json", 7 * 86400
  local KNOWN = {}
  for _, f in ipairs(FLAGS) do KNOWN[f] = true end
  local function overlay(base, extra)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    if type(extra) == "table" then
      for k, v in pairs(extra) do
        if tonumber(k) and type(v) == "string" and KNOWN[v] then out[tostring(k)] = v end -- chỉ nhận cờ đã biết
      end
    end
    return out
  end
  local remote = { places = nil, universes = nil }
  local function loadCache()
    if remote.places or remote.universes then return end
    pcall(function()
      if isfile and readfile and isfile(PLACES_FILE) then
        local c = game:GetService("HttpService"):JSONDecode(readfile(PLACES_FILE))
        if type(c) == "table" and os.time() - (tonumber(c.t) or 0) < PLACES_TTL then
          remote.places, remote.universes = c.places, c.universes
        end
      end
    end)
  end
  _G.HzPlacesApply = function(db) -- gọi sau khi scripts.json về; true nếu DB có places/universes
    if type(db) ~= "table" or (type(db.places) ~= "table" and type(db.universes) ~= "table") then return false end
    remote.places, remote.universes = db.places, db.universes
    pcall(function()
      if writefile then
        if makefolder and isfolder and not isfolder("x8k2") then makefolder("x8k2") end
        writefile(PLACES_FILE, game:GetService("HttpService"):JSONEncode({ t = os.time(), places = db.places, universes = db.universes }))
      end
    end)
    return true
  end

  local function toKey(n)
    n = tonumber(n)
    if not n then return nil end
    local ok, s = pcall(string.format, "%.0f", n)
    if ok and type(s) == "string" then return s end
    return tostring(n)
  end

  local function lowerSafe(s)
    if type(s) == "string" then
      local ok, r = pcall(string.lower, s)
      if ok and type(r) == "string" then return r end
    end
    return ""
  end

  local function lookup(map, vals)
    for _, v in ipairs(vals) do
      local n = tonumber(v)
      if n and n ~= 0 then
        local k = toKey(n)
        if k and map[k] then return map[k], k end
        for ks, flag in pairs(map) do
          if tonumber(ks) == n then return flag, ks end
        end
      end
    end
    return nil, nil
  end

  local function firstNum(vals)
    for _, v in ipairs(vals) do
      local n = tonumber(v)
      if n and n ~= 0 then return n end
    end
    return 0
  end

  local function logMsg(msg, lvl)
    local f = _G.aa3542001e064bc52
    local ok = false
    if type(f) == "function" then ok = pcall(f, msg, lvl) end
    if not ok then pcall(print, msg) end
  end

  local function core(placeId, universeId, gameName)
    loadCache() -- [V35] C1
    local PLACE_MAP = overlay(DEFAULT_PLACES, remote.places)
    local UNI_MAP = overlay(DEFAULT_UNIVERSES, remote.universes)

    local pvals, uvals = {}, {}
    if placeId ~= nil then pvals[#pvals + 1] = placeId end
    if universeId ~= nil then uvals[#uvals + 1] = universeId end
    pcall(function() pvals[#pvals + 1] = game.PlaceId end)
    pcall(function() uvals[#uvals + 1] = game.GameId end)
    local pNum, uNum = firstNum(pvals), firstNum(uvals)

    local F = {}
    for _, name in ipairs(FLAGS) do F[name] = false end

    local hit = lookup(PLACE_MAP, pvals)
    local matchBy = hit and "PlaceId" or nil
    if not hit then
      hit = lookup(UNI_MAP, uvals)
      if hit then matchBy = "UniverseId" end
    end
    if hit then F[hit] = true end

    local names = {}
    local function addName(s)
      if type(s) == "string" and s ~= "" and s ~= "Unknown" then names[#names + 1] = s end
    end
    addName(gameName)
    local engineName
    pcall(function() engineName = game.Name end)
    addName(engineName)
    if #names == 0 and not hit then addName(_G.HzFetchGameName(pNum, 3)) end

    if not hit then
      local low = lowerSafe(table.concat(names, " | "))
      local function has(s)
        s = tostring(s)
        if low == "" or s == "" then return false end
        local ok, r = pcall(string.find, low, s, 1, true)
        if ok then return r ~= nil end
        for i = 1, #low - #s + 1 do
          if string.sub(low, i, i + #s - 1) == s then return true end
        end
        return false
      end

      F.isJumpShowdown = has("jump showdown") or has("jump showndown")
      F.isJJS = not F.isJumpShowdown and (has("jujutsu") or has("shenanigan") or has("jjs"))
      F.isTSB = not F.isJumpShowdown and not F.isJJS and has("strongest")
      F.isBloxFruit = not F.isJumpShowdown and not F.isJJS and not F.isTSB and has("blox fruit")
      F.isEscapeTsunami = has("escape tsunami")
      F.isTitanFishing = has("titan-fishing") or has("titan fishing")
      if not F.isTitanFishing then
        if has("fish it") then F.isFishIt = true
        elseif has("fish") then F.isFish = true end
      end
      F.isMM2 = has("murder mystery 2") or has("mm2")
      F.isGardenHorizons = has("garden horizons")
      F.isEvadeGame = has("evade")
      F.isDoors = has("doors")
      F.is99Nights = has("99 nights in forest")
      F.isKnockout = has("knockout")
      F.isStealAnEgg = has("steal an egg") or (has("steal") and has("egg") and not has("steal a egg"))
      F.isKingLegacy = has("king legacy")
      for _, name in ipairs(FLAGS) do
        if F[name] then matchBy = "GameName" break end
      end
    end

    local any = false
    for _, name in ipairs(FLAGS) do
      if F[name] == true then any = true break end
    end
    F.any = any

    local parts = {}
    for _, name in ipairs(FLAGS) do parts[#parts + 1] = name .. "=" .. tostring(F[name]) end
    parts[#parts + 1] = "any=" .. tostring(any)
    logMsg(string.format("[HzDetect] PlaceId=%s | UniverseId=%s | GameName=%s | game.Name=%s | matchBy=%s",
      tostring(toKey(pNum)), tostring(toKey(uNum)), tostring(names[1] or "Unknown"),
      tostring(engineName), tostring(matchBy or "none")), any and "INFO" or "WARN")
    logMsg("[HzDetect] " .. table.concat(parts, " "), any and "INFO" or "WARN")

    pcall(function()
      _G.HzDetectInfo = { placeId = pNum, universeId = uNum, gameName = names[1], engineName = engineName, matchBy = matchBy, flags = F }
    end)
    return F
  end

  return function(placeId, universeId, gameName)
    local ok, r = pcall(core, placeId, universeId, gameName)
    if ok and type(r) == "table" then return r end
    logMsg("[HzDetect] LỖI nhận diện game: " .. tostring(r), "ERROR")
    return { any = false }
  end
end)()

-- API: _G.HzAutoload.load() / .save() / .isPinned(url) / .toggle(name, url) / .remove(url) / .clear() / .count() / .names() / .runAll(token)
_G.HzAutoloadOn = true -- tắt/mở ở Cài đặt → ⭐ Tự động chạy
if _G.HzFeedbackKey == nil then _G.HzFeedbackKey = "hiulzhub190212" end
_G.HzAutoload = (function()
  local HttpService = game:GetService("HttpService")
  local DIR, FILE, MAXN = "x8k2", "x8k2/autoload.json", ((_G.HzConst or {}).autoload or {}).maxPins or 20 -- [V35]
  local A = { list = nil, onChange = nil }

  local function fsOK() return type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function" end

  local TRUSTED = { ["raw.githubusercontent.com"] = true, ["api.luarmor.net"] = true, ["scriptblox.com"] = true }
  local warned = {}
  local function checkHost(url)
    if type(url) ~= "string" or warned[url] then return end
    local host = url:match("^https://([^/:?#]+)")
    if host and TRUSTED[host:lower()] then return end
    warned[url] = true
    pcall(function()
      if _G.aa3542001e064bc52 then
        _G.aa3542001e064bc52("Autoload: link ngoài host tin cậy — " .. (url:match("^https://[^?#]+") or "?"):sub(1, 90), "WARN")
      end
    end)
  end

  local function clean(src) -- chỉ giữ { name, url }, url phải là https và không trùng
    local out, seen = {}, {}
    if type(src) == "table" then
      local arr = type(src.scripts) == "table" and src.scripts or src
      for _, e in ipairs(arr) do
        if type(e) == "table" and type(e.url) == "string" and e.url:sub(1, 8) == "https://"
          and #e.url <= 300 and not seen[e.url] and #out < MAXN then
          seen[e.url] = true
          checkHost(e.url)
          out[#out + 1] = { name = (type(e.name) == "string" and e.name ~= "") and e.name:sub(1, 40) or "Script", url = e.url }
        end
      end
    end
    return out
  end

  function A.load()
    local ok, d = pcall(function()
      if fsOK() and isfile(FILE) then return HttpService:JSONDecode(readfile(FILE)) end
    end)
    if ok and d ~= nil then
      A.list = clean(d)
    else
      A.list = clean(_G.HzAutoloadMem) -- bản dự phòng trong RAM nếu executor không có writefile
    end
    return A.list
  end

  local function ensure() return A.list or A.load() end

  function A.save()
    local list = ensure()
    _G.HzAutoloadMem = { version = 1, scripts = list }
    if not fsOK() then return false end
    return (pcall(function()
      if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(DIR) then makefolder(DIR) end
      writefile(FILE, HttpService:JSONEncode({ version = 1, scripts = list }))
    end))
  end

  local function changed()
    if type(A.onChange) == "function" then pcall(A.onChange) end
  end

  function A.count() return #ensure() end

  function A.names()
    local t = {}
    for _, e in ipairs(ensure()) do t[#t + 1] = e.name end
    return t
  end

  function A.isPinned(url)
    if type(url) ~= "string" then return false end
    for _, e in ipairs(ensure()) do if e.url == url then return true end end
    return false
  end

  function A.remove(url)
    local list = ensure()
    for i, e in ipairs(list) do
      if e.url == url then
        table.remove(list, i)
        A.save()
        changed()
        return true
      end
    end
    return false
  end

  -- Trả về "pinned" | "unpinned" | "full" | "bad"
  function A.toggle(name, url)
    if type(url) ~= "string" or url:sub(1, 8) ~= "https://" or #url > 300 then return "bad" end
    if A.isPinned(url) then
      A.remove(url)
      return "unpinned"
    end
    local list = ensure()
    if #list >= MAXN then return "full" end
    checkHost(url)
    list[#list + 1] = { name = (type(name) == "string" and name ~= "") and name:sub(1, 40) or "Script", url = url }
    A.save()
    changed()
    return "pinned"
  end

  function A.clear()
    A.list = {}
    A.save()
    changed()
  end

  -- Chạy lần lượt các script đã ghim (dùng safeLoad; lỗi → _G.HzLogError). token = số lần execute hiện tại.
  function A.runAll(token)
    if _G.HzAutoloadOn == false then return 0 end
    if _G.f8eefa956e6130f83 then -- chế độ "chỉ copy": không tự chạy gì cả
      if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Autoload: bỏ qua (đang ở chế độ chỉ copy)", "WARN") end
      return 0
    end
    local list = {}
    for i, e in ipairs(ensure()) do list[i] = e end
    task.spawn(function()
      for _, e in ipairs(list) do
        if token ~= nil and token ~= _G.d8e1181c0775aa002 then return end -- đã có lần execute mới hơn
        if _G.HzAutoloadOn == false then return end
        local ok, err = pcall(function()
          if type(safeLoad) == "function" then
            safeLoad(e.name, e.url)
          else
            local fn, cerr = loadstring(game:HttpGet(e.url, true))
            if not fn then error(cerr or "syntax error", 0) end
            fn()
          end
        end)
        if not ok then _G.HzLogError(err, "Autoload: " .. tostring(e.name)) end
        task.wait(0.6)
      end
    end)
    return #list
  end

  return A
end)()

_G.HzAutoRestore = (function()
  local HttpService = game:GetService("HttpService")
  local DIR, FILE, FLAG_FILE, PENDING_FILE = "x8k2", "x8k2/run_history.json", "x8k2/autorestore.json", "x8k2/restore_pending.json"
  local MAX_KEEP, MAX_RUN, MAX_RUN_LITE, PENDING_TTL = 20, 5, 3, 900
  local SOURCES = { db = true, vault = true, scriptblox = true }
  local DEFAULT_HUB = "https://raw.githubusercontent.com/chihieudz19/OnTop/refs/heads/main/obf_hiulz.lua"
  local A = { list = nil, jobId = nil, onChange = nil }

  local function fsOK() return type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function" end

  local function log(msg, level)
    pcall(function()
      if type(_G.aa3542001e064bc52) == "function" then _G.aa3542001e064bc52(msg, level or "INFO") end
    end)
  end

  local function cut(s, n)
    local ok, r = pcall(function()
      local len = utf8.len(s)
      if len and len > n then return s:sub(1, utf8.offset(s, n + 1) - 1) end
      return s
    end)
    if ok and type(r) == "string" then return r end
    return s
  end

  local function writeJson(path, data)
    if not fsOK() then return false end
    return (pcall(function()
      if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(DIR) then makefolder(DIR) end
      writefile(path, HttpService:JSONEncode(data))
    end))
  end

  local function readJson(path)
    if not fsOK() then return nil end
    local ok, d = pcall(function()
      if isfile(path) then return HttpService:JSONDecode(readfile(path)) end
    end)
    if ok and type(d) == "table" then return d end
    return nil
  end

  local function changed()
    if type(A.onChange) == "function" then pcall(A.onChange) end
  end

  local function cleanEnv(g)
    if type(g) ~= "table" then return nil end
    local out, n = {}, 0
    for k, v in pairs(g) do
      if n >= 12 then break end
      local tv = type(v)
      if type(k) == "string" and #k <= 40 and (tv == "boolean" or tv == "number" or (tv == "string" and #v <= 200)) then
        out[k] = v
        n = n + 1
      end
    end
    if n == 0 then return nil end
    return out
  end

  local function cleanKey(k)
    if type(k) == "string" and k ~= "" and #k <= 200 then return k end
    return nil
  end

  local function clean(src) -- chỉ giữ { name, url, source, ts, genv, key }; url https, nguồn hợp lệ, không trùng, tối đa MAX_KEEP
    local out, seen = {}, {}
    if type(src) == "table" then
      local arr = type(src.scripts) == "table" and src.scripts or src
      for _, e in ipairs(arr) do
        if type(e) == "table" and type(e.url) == "string" and e.url:sub(1, 8) == "https://" and #e.url <= 300
          and SOURCES[e.source] and not seen[e.url] then
          seen[e.url] = true
          out[#out + 1] = {
            name = (type(e.name) == "string" and e.name ~= "") and cut(e.name, 40) or "Script",
            url = e.url, source = e.source, ts = tonumber(e.ts) or 0,
            genv = cleanEnv(e.genv), key = cleanKey(e.key),
          }
        end
      end
    end
    while #out > MAX_KEEP do table.remove(out, 1) end
    return out
  end

  function A.load()
    pcall(function()
      local d = readJson(FILE)
      if d == nil then d = _G.HzRunHistory end -- bản dự phòng trong RAM nếu executor không có writefile
      A.jobId = (type(d) == "table" and type(d.jobId) == "string") and d.jobId or nil
      A.list = clean(d)
    end)
    if type(A.list) ~= "table" then A.list = {} end
    return A.list
  end

  local function ensure() return A.list or A.load() end

  function A.save()
    local ok, res = pcall(function()
      local data = { version = 1, jobId = tostring(game.JobId), scripts = ensure() }
      A.jobId = data.jobId
      _G.HzRunHistory = data
      return writeJson(FILE, data)
    end)
    return ok and res == true
  end

  -- extra (tuỳ chọn): { genv = {...} } cho script ở danh sách, { key = "..." } cho script ở Kho
  function A.track(name, url, source, extra)
    pcall(function()
      if type(url) ~= "string" or url:sub(1, 8) ~= "https://" or #url > 300 then return end
      if not SOURCES[source] then return end
      if _G.f8eefa956e6130f83 == true then return end -- chế độ chỉ copy: script không thực sự chạy
      local list = ensure()
      for i, e in ipairs(list) do
        if e.url == url then table.remove(list, i) break end -- đã có: bỏ bản cũ rồi ghi lại với ts mới (không thêm trùng)
      end
      local nm = (type(name) == "string" and name ~= "") and cut(name, 40) or "Script"
      list[#list + 1] = {
        name = nm, url = url, source = source, ts = os.time(),
        genv = cleanEnv(type(extra) == "table" and extra.genv or nil),
        key = cleanKey(type(extra) == "table" and extra.key or nil),
      }
      while #list > MAX_KEEP do table.remove(list, 1) end -- cắt bản cũ nhất
      log("AutoRestore: đã ghi nhận " .. nm, "INFO")
      task.defer(function() -- không làm chậm nút bấm
        A.save()
        changed()
      end)
    end)
  end

  function A.count()
    local ok, n = pcall(function() return #ensure() end)
    return ok and n or 0
  end

  function A.names()
    local t = {}
    pcall(function() for _, e in ipairs(ensure()) do t[#t + 1] = e.name end end)
    return t
  end

  function A.has(url)
    local ok, r = pcall(function()
      for _, e in ipairs(ensure()) do if e.url == url then return true end end
      return false
    end)
    return ok and r == true
  end

  function A.sameJob()
    local ok, same = pcall(function()
      local d = readJson(FILE)
      if d == nil then d = _G.HzRunHistory end
      local old = type(d) == "table" and d.jobId or nil
      return type(old) == "string" and old ~= "" and old == tostring(game.JobId)
    end)
    return ok and same == true
  end

  function A.shouldRun()
    local ok, r = pcall(function()
      return _G.HzAutoRestoreScripts == true and _G.f8eefa956e6130f83 ~= true
        and _G.HzRestorePromptedThisSession ~= true and A.count() > 0 and not A.sameJob()
    end)
    return ok and r == true
  end

  function A.clear()
    pcall(function()
      A.list, A.jobId = {}, nil
      _G.HzRunHistory = nil
      writeJson(FILE, { version = 1, scripts = {} })
      log("AutoRestore: đã xoá lịch sử", "INFO")
      changed()
    end)
  end

  -- ===== Công tắc (nhớ ở x8k2/autorestore.json, ngoài Flag của Gen2) =====
  local function saveFlags()
    writeJson(FLAG_FILE, { version = 1, enabled = _G.HzAutoRestoreScripts == true, kick = _G.HzAutoRestoreKick == true, reload = _G.HzAutoHubReload ~= false, hub = A.hub })
  end

  function A.setEnabled(v)
    pcall(function()
      _G.HzAutoRestoreScripts = (v == true)
      saveFlags()
    end)
  end

  -- ===== Chạy lại =====
  local function applyEnv(e) -- đặt biến môi trường giống lúc bấm Chạy lần đầu
    pcall(function()
      if type(getgenv) ~= "function" then return end
      local g = getgenv()
      if type(e.genv) == "table" then for k, v in pairs(e.genv) do g[k] = v end end
      if type(e.key) == "string" and e.key ~= "" then g.script_key = e.key end
    end)
  end

  -- Danh sách sẽ chạy: bỏ link không https, bỏ script đã ghim Auto-run (tránh chạy 2 lần), giữ các script dùng gần nhất
  local function buildQueue()
    local lite = _G.HzLiteLoad == true
    local maxRun = lite and MAX_RUN_LITE or MAX_RUN
    local q = {}
    for _, e in ipairs(ensure()) do
      if type(e.url) == "string" and e.url:sub(1, 8) == "https://" then
        local pinned = false
        pcall(function() pinned = _G.HzAutoload ~= nil and _G.HzAutoload.isPinned(e.url) == true end)
        if pinned then
          log("AutoRestore: bỏ qua " .. e.name .. " (đã có Auto-run)", "INFO")
        else
          q[#q + 1] = e
        end
      end
    end
    while #q > maxRun do table.remove(q, 1) end
    return q, (lite and 1.2 or 0.9)
  end

  -- keep = true: chạy xong vẫn giữ danh sách (dùng cho chế độ kick để lần kick sau vẫn chạy lại được)
  function A.runAll(token, keep)
    local ok, total = pcall(function()
      if _G.f8eefa956e6130f83 == true then
        log("AutoRestore: bỏ qua (chế độ chỉ copy)", "WARN")
        return 0
      end
      local queue, gap = buildQueue()
      task.spawn(function()
        for _, e in ipairs(queue) do
          if token ~= nil and token ~= _G.d8e1181c0775aa002 then return end -- đã có lần execute mới hơn
          log("AutoRestore: chạy lại " .. e.name, "INFO")
          local okRun, err = pcall(function()
            if type(safeLoad) ~= "function" then error("safeLoad chưa sẵn sàng", 0) end
            applyEnv(e)
            safeLoad(e.name, e.url)
          end)
          if not okRun then
            log("AutoRestore: lỗi " .. e.name .. " - " .. tostring(err), "WARN")
            pcall(function() _G.HzLogError(err, "AutoRestore: " .. tostring(e.name)) end)
          end
          task.wait(gap)
        end
        if keep ~= true and (token == nil or token == _G.d8e1181c0775aa002) then A.clear() end -- chạy xong thì quên luôn
      end)
      return #queue
    end)
    return ok and total or 0
  end

  -- ===== Chế độ kick / mất kết nối =====
  local function queueFn()
    if type(queue_on_teleport) == "function" then return queue_on_teleport end
    if type(queueonteleport) == "function" then return queueonteleport end
    if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then return syn.queue_on_teleport end
    if type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then return fluxus.queue_on_teleport end
    return nil
  end

  -- Mã nhỏ chạy ở server mới (không cần hub): kiểm tra công tắc + đúng game, chặn chạy 2 lần, rồi chạy tuần tự
  local BOOT_SRC = [==[
local data = %q
task.spawn(function()
  local HttpService = game:GetService("HttpService")
  local ok, d = pcall(function() return HttpService:JSONDecode(data) end)
  if not ok or type(d) ~= "table" or type(d.list) ~= "table" then return end
  if d.place and game.PlaceId ~= d.place then return end
  local off = false
  pcall(function()
    if type(isfile) == "function" and type(readfile) == "function" and isfile("x8k2/autorestore.json") then
      local f = HttpService:JSONDecode(readfile("x8k2/autorestore.json"))
      if type(f) == "table" and f.kick == false then off = true end
    end
  end)
  if off then return end
  local g = (type(getgenv) == "function") and getgenv() or _G
  if type(g.HzRestoreBootAt) == "number" and os.time() - g.HzRestoreBootAt < 120 then return end
  g.HzRestoreBootAt = os.time()
  if not game:IsLoaded() then game.Loaded:Wait() end
  task.wait(6)
  for _, e in ipairs(d.list) do
    if type(e) == "table" and type(e.url) == "string" and e.url:sub(1, 8) == "https://" then
      pcall(function()
        if type(e.genv) == "table" then
          for k, v in pairs(e.genv) do
            local tv = type(v)
            if type(k) == "string" and (tv == "string" or tv == "number" or tv == "boolean") then g[k] = v end
          end
        end
        if type(e.key) == "string" and e.key ~= "" then g.script_key = e.key end
        local fn = loadstring(game:HttpGet(e.url, true))
        if fn then fn() end
      end)
      task.wait(tonumber(d.gap) or 0.9)
    end
  end
end)
]==]

  function A.bootstrap(queue, gap)
    local items = {}
    for _, e in ipairs(queue) do items[#items + 1] = { name = e.name, url = e.url, genv = e.genv, key = e.key } end
    return string.format(BOOT_SRC, HttpService:JSONEncode({ gap = gap, place = game.PlaceId, list = items }))
  end

  local function validHub(s)
    if type(s) ~= "string" then return nil end
    s = (s:gsub("^%s+", ""))
    s = (s:gsub("%s+$", ""))
    if s == "" then return "" end
    if s:sub(1, 8) == "https://" then
      if #s <= 300 and not s:find("%s") then return s end
      return nil
    end
    if #s <= 80 and not s:find("..", 1, true) and s:sub(1, 1) ~= "/" and s:sub(1, 1) ~= "\\" and s:match("^[%w_%-%./ ]+$") then return s end
    return nil
  end

  function A.getHubSource() return A.hub end

  function A.setHubSource(text) -- trả về (true, "saved"/"cleared") hoặc (false, "bad")
    local ok, res, how = pcall(function()
      local v = validHub(text)
      if v == nil then return false, "bad" end
      A.hub = (v ~= "") and v or nil
      saveFlags()
      return true, (v == "") and "cleared" or "saved"
    end)
    if ok then return res, how end
    return false, "bad"
  end

  -- Mã nhỏ nạp lại chính hub ở server mới: đợi game tải xong, bỏ qua nếu hub đã chạy (autoexec) hoặc công tắc kick đã tắt
  local HUB_SRC = [==[
local src = %q
task.spawn(function()
  local HttpService = game:GetService("HttpService")
  local off = false
  pcall(function()
    if type(isfile) == "function" and type(readfile) == "function" and isfile("x8k2/autorestore.json") then
      local f = HttpService:JSONDecode(readfile("x8k2/autorestore.json"))
      if type(f) == "table" and f.reload == false and f.kick ~= true then off = true end
    end
  end)
  if off then return end
  local g = (type(getgenv) == "function") and getgenv() or _G
  if type(g.HzHubBootAt) == "number" and os.time() - g.HzHubBootAt < 120 then return end
  g.HzHubBootAt = os.time()
  if not game:IsLoaded() then game.Loaded:Wait() end
  task.wait(4)
  if _G.e8aabebd23a37913d == true then return end
  local code
  if src:sub(1, 8) == "https://" then
    local ok, r = pcall(function() return game:HttpGet(src, true) end)
    if ok then code = r end
  elseif type(isfile) == "function" and type(readfile) == "function" and isfile(src) then
    local ok, r = pcall(readfile, src)
    if ok then code = r end
  end
  if type(code) == "string" and code ~= "" then
    local fn = loadstring(code)
    if fn then pcall(fn) end
  end
end)
]==]

  function A.hubBootstrap(src) return string.format(HUB_SRC, src) end

  -- Nguồn hub sẽ nạp lại: link/file người dùng đặt, nếu trống và công tắc nạp lại hub bật thì dùng link mặc định
  function A.hubSource()
    if A.hub then return A.hub end
    if _G.HzAutoHubReload ~= false then return DEFAULT_HUB end
    return nil
  end

  -- Hẹn nạp hub ở server mới. Chống hẹn dồn trong 20 giây (mã chạy ở server mới cũng tự chặn chạy 2 lần)
  local function queueHubNow(src, why)
    local q = queueFn()
    if not q or type(src) ~= "string" or src == "" then return false end
    if os.clock() - (_G.HzHubQueuedAt or -1000) < 20 then return true end
    _G.HzHubQueuedAt = os.clock()
    q(A.hubBootstrap(src))
    log("AutoRestore: đã hẹn nạp lại hub khi vào server mới (" .. tostring(why) .. ")", "INFO")
    return true
  end

  function A.queueHub(why)
    local ok, r = pcall(function()
      if _G.f8eefa956e6130f83 == true or _G.HzAutoHubReload == false then return false end
      return queueHubNow(A.hubSource(), why)
    end)
    return ok and r == true
  end
  _G.HzQueueHubReload = function(why) return A.queueHub(why) end

  -- Gọi khi phát hiện kick/mất kết nối: ghi dấu "vừa bị kick" + hẹn chạy lại script đã giữ (và hub nếu có đặt nguồn) ở server mới
  function A.arm(why)
    pcall(function()
      if _G.f8eefa956e6130f83 == true then return end
      local kickOn = _G.HzAutoRestoreKick == true
      local queue, gap = {}, 0.9
      if kickOn then queue, gap = buildQueue() end
      local hubSrc = A.hubSource()
      if #queue == 0 and not hubSrc then
        log("AutoRestore: không có script nào để chạy lại", "INFO")
        return
      end
      if kickOn then writeJson(PENDING_FILE, { version = 1, ts = os.time(), place = game.PlaceId, reason = tostring(why) }) end
      local q = queueFn()
      if q then
        if #queue > 0 then q(A.bootstrap(queue, gap)) end -- script trước (đặt dấu chống chạy trùng), hub sau
        if hubSrc then queueHubNow(hubSrc, why) end
        log("AutoRestore: phát hiện " .. tostring(why) .. " — đã hẹn chạy lại " .. #queue .. " script" .. (hubSrc and " và nạp lại hub" or "") .. " khi vào server mới", "WARN")
      else
        log("AutoRestore: executor không có queue_on_teleport — script sẽ chạy lại khi bạn execute hub", "WARN")
      end
    end)
  end

  function A.pendingFresh()
    local ok, r = pcall(function()
      local d = readJson(PENDING_FILE)
      local ts = type(d) == "table" and tonumber(d.ts) or nil
      return ts ~= nil and ts > 0 and os.time() - ts < PENDING_TTL and d.place == game.PlaceId
    end)
    return ok and r == true
  end

  function A.clearPending()
    pcall(function() writeJson(PENDING_FILE, { version = 1, ts = 0 }) end)
  end

  function A.bootDone() -- mã hẹn giờ (queue_on_teleport) đã chạy ở phiên này → hub không chạy lại nữa
    local ok, r = pcall(function()
      local g = (type(getgenv) == "function") and getgenv() or _G
      return type(g.HzRestoreBootAt) == "number" and os.time() - g.HzRestoreBootAt < 600
    end)
    return ok and r == true
  end

  -- Nghe bảng lỗi của Roblox (kick, mất kết nối...) — chỉ 1 kết nối sự kiện, không vòng lặp, chống kích hoạt dồn trong 20 giây
  function A.watch(on)
    pcall(function()
      _G.HzRestoreWatchToken = (_G.HzRestoreWatchToken or 0) + 1
      local token, exe = _G.HzRestoreWatchToken, _G.d8e1181c0775aa002
      if type(_G.HzRestoreConns) == "table" then
        for _, c in ipairs(_G.HzRestoreConns) do pcall(function() c:Disconnect() end) end
      end
      local conns = {}
      _G.HzRestoreConns = conns
      if on ~= true then return end
      local last = -1000
      local function alive()
        return token == _G.HzRestoreWatchToken and exe == _G.d8e1181c0775aa002 and (_G.HzAutoRestoreKick == true or _G.HzAutoHubReload ~= false)
      end
      local GuiService = game:GetService("GuiService")
      conns[#conns + 1] = GuiService.ErrorMessageChanged:Connect(function()
        pcall(function()
          if not alive() or os.clock() - last < 20 then return end
          local msg = GuiService:GetErrorMessage()
          if type(msg) ~= "string" or msg == "" then return end
          last = os.clock()
          A.arm("kick hoặc mất kết nối")
        end)
      end)
      log("AutoRestore: đang theo dõi kick và mất kết nối", "INFO")
    end)
  end

  function A.wantWatch()
    return _G.HzAutoRestoreKick == true or _G.HzAutoHubReload ~= false
  end

  -- Nghe LocalPlayer.OnTeleport: mọi lần dịch chuyển (đổi server, vào lại, Auto Rejoin, game tự teleport) đều hẹn nạp lại hub
  function A.watchTeleport(on)
    pcall(function()
      _G.HzHubTpToken = (_G.HzHubTpToken or 0) + 1
      local token, exe = _G.HzHubTpToken, _G.d8e1181c0775aa002
      if type(_G.HzHubTpConns) == "table" then
        for _, c in ipairs(_G.HzHubTpConns) do pcall(function() c:Disconnect() end) end
      end
      local conns = {}
      _G.HzHubTpConns = conns
      if on ~= true then return end
      local lp = game:GetService("Players").LocalPlayer
      if not lp then return end
      conns[#conns + 1] = lp.OnTeleport:Connect(function(state)
        pcall(function()
          if token ~= _G.HzHubTpToken or exe ~= _G.d8e1181c0775aa002 or _G.HzAutoHubReload == false then return end
          if state == Enum.TeleportState.Started or state == Enum.TeleportState.RequestedFromServer or state == Enum.TeleportState.InProgress then
            A.queueHub("teleport")
          end
        end)
      end)
      log("AutoRestore: đang theo dõi teleport để nạp lại hub", "INFO")
    end)
  end

  function A.setKick(v)
    pcall(function()
      _G.HzAutoRestoreKick = (v == true)
      saveFlags()
      A.watch(A.wantWatch())
    end)
  end

  function A.setReload(v)
    pcall(function()
      _G.HzAutoHubReload = (v == true)
      saveFlags()
      A.watch(A.wantWatch())
      A.watchTeleport(v == true)
    end)
  end

  -- Popup hỏi. _G.HzConfirm không có callback cho nút Hủy, nên gọi thẳng Popup (cùng kiểu với HzConfirm)
  -- để bắt được onNo; không có Popup thì dùng _G.HzConfirm (nó sẽ chạy thẳng onYes như fallback hiện tại).
  function A.prompt(onYes, onNo)
    pcall(function()
      local T = _G.gL22 and function(x) return x end or _G.tR9
      local title, okText = "Khôi phục script?", "Chạy lại"
      local fmt = "Bạn đã bật %d script từ danh sách script. Muốn tự động chạy lại khi vào server này?"
      local content = string.format(type(_G.tR9) == "function" and _G.tR9(fmt) or fmt, A.count())
      local function yes() if type(onYes) == "function" then pcall(onYes) end end
      local function no()
        log("AutoRestore: người dùng từ chối", "INFO")
        if type(onNo) == "function" then pcall(onNo) end
      end
      local shown = false
      local win = _G.rW15
      if win and type(win.Popup) == "function" and not win.unloaded then
        shown = pcall(function()
          win:Popup({
            title = T(title), content = T(content),
            options = {
              { text = T("Hủy"), style = "neutral", callback = function() task.defer(no) end },
              { text = T(okText), style = "danger", callback = function() task.defer(yes) end },
            },
            dismissable = true,
          })
        end)
      end
      if not shown then _G.HzConfirm(title, content, okText, yes) end
    end)
  end

  pcall(function()
    if _G.HzAutoRestoreScripts == nil or _G.HzAutoRestoreKick == nil then
      local d = readJson(FLAG_FILE)
      if _G.HzAutoRestoreScripts == nil then _G.HzAutoRestoreScripts = (type(d) == "table" and d.enabled == true) end
      if _G.HzAutoRestoreKick == nil then _G.HzAutoRestoreKick = (type(d) == "table" and d.kick == true) end
    end
  end)
  pcall(function()
    local d = readJson(FLAG_FILE)
    if type(d) == "table" and type(d.hub) == "string" and d.hub ~= "" then A.hub = d.hub end
  end)
  pcall(function()
    if _G.HzAutoHubReload == nil then
      local d = readJson(FLAG_FILE)
      _G.HzAutoHubReload = not (type(d) == "table" and d.reload == false) -- mặc định BẬT
    end
    A.watchTeleport(_G.HzAutoHubReload ~= false)
  end)

  return A
end)()

-- _G.HzPrivacyName = true  → hiện tên đã che (giữ 3 ký tự đầu, từ ký tự thứ 4 trở đi thay bằng "*"; ví dụ meomaybeo1912 → meo**********)
-- _G.HzPrivacyName = false → hiện tên thật. Mặc định BẬT; đổi ở Cài đặt → Hệ thống → 👁️ Ẩn tên người chơi (Mask).
-- _G.HzMaskName(str)            : che chuỗi (tên dưới 4 ký tự thì giữ nguyên)
-- _G.HzDisplayName([tên_thật])  : tên để hiển thị theo trạng thái Toggle (mặc định lấy LocalPlayer.Name)
-- _G.HzPatchRayfieldName(root)  : quét nhãn chữ trong `root` (ScreenGui của menu) rồi che / hiện lại tên Roblox của bạn
if _G.HzPrivacyName == nil then _G.HzPrivacyName = true end
_G.HzNeutralName = "Player" -- giữ lại để tương thích bản cũ (không còn là tên hiển thị mặc định)

_G.HzMaskName = function(str)
  if type(str) ~= "string" then return str end
  local ok, res = pcall(function()
    local n = utf8 and utf8.len(str) -- đếm theo ký tự (tên Unicode); nil nếu chuỗi UTF-8 lỗi
    if n then
      if n < 4 then return str end
      local cut = utf8.offset(str, 4) -- vị trí byte của ký tự thứ 4
      if not cut then return str end
      return str:sub(1, cut - 1) .. string.rep("*", n - 3)
    end
    if #str < 4 then return str end
    return str:sub(1, 3) .. string.rep("*", #str - 3)
  end)
  if ok and type(res) == "string" then return res end
  return str
end

_G.HzDisplayName = function(real)
  if type(real) ~= "string" or real == "" then
    real = "Player"
    pcall(function()
      local lp = game:GetService("Players").LocalPlayer
      if lp then real = tostring(lp.Name) end
    end)
  end
  if _G.HzPrivacyName == false then return real end
  return _G.HzMaskName(real)
end

_G.HzPatchRayfieldName = function(root)
  if typeof(root) ~= "Instance" then return 0 end
  local lp = game:GetService("Players").LocalPlayer
  if not lp then return 0 end
  local nm, dn = tostring(lp.Name or ""), tostring(lp.DisplayName or "")
  local nml, dnl = nm:lower(), dn:lower()
  local mine = {}
  for _, s in ipairs({ nml, dnl }) do
    if s ~= "" then mine[s] = true mine["@" .. s] = true end
  end
  if nml ~= "" and dnl ~= "" then
    mine[dnl .. " (@" .. nml .. ")"] = true
    mine[nml .. " (" .. dnl .. ")"] = true
  end
  local function isMine(t)
    if type(t) ~= "string" or t == "" or #t > 80 then return false end
    local s = (t:gsub("<[^>]+>", "")):lower() -- bỏ thẻ RichText
    s = s:match("^%s*(.-)%s*$") or s
    return mine[s] == true
  end
  local function repCI(str, needle, rep) -- thay chuỗi, không phân biệt hoa/thường
    if needle == "" then return str end
    local ls, ln = str:lower(), needle:lower()
    local out, i = {}, 1
    while true do
      local a, b = ls:find(ln, i, true)
      if not a then break end
      out[#out + 1] = str:sub(i, a - 1)
      out[#out + 1] = rep
      i = b + 1
    end
    out[#out + 1] = str:sub(i)
    return table.concat(out)
  end
  local function target(orig) -- chữ cần hiển thị cho nhãn có chữ gốc `orig` (theo Toggle Mask hiện tại)
    if _G.HzPrivacyName == false then return orig end
    local a, b = nm, dn
    if #b > #a then a, b = b, a end
    local out = orig
    if a ~= "" then out = repCI(out, a, _G.HzMaskName(a)) end
    if b ~= "" and b:lower() ~= a:lower() then out = repCI(out, b, _G.HzMaskName(b)) end
    return out
  end

  local hooked = _G.HzNameHooked
  if type(hooked) ~= "table" then
    hooked = setmetatable({}, { __mode = "k" })
    _G.HzNameHooked = hooked
  end
  local origT = _G.HzNameOrig -- chữ gốc (tên thật) của từng nhãn đã nhận diện
  if type(origT) ~= "table" then
    origT = setmetatable({}, { __mode = "k" })
    _G.HzNameOrig = origT
  end
  local shownT = _G.HzNameShown -- chữ mà script đã ghi lần cuối vào nhãn
  if type(shownT) ~= "table" then
    shownT = setmetatable({}, { __mode = "k" })
    _G.HzNameShown = shownT
  end

  local n = 0
  local function apply(inst) -- đặt chữ của nhãn theo trạng thái Mask hiện tại (che hoặc trả lại tên thật)
    local o = origT[inst]
    if o == nil then return end
    local okT, cur = pcall(function() return inst.Text end)
    if not okT then return end
    if cur ~= shownT[inst] and not isMine(cur) then -- nhãn đã đổi sang chữ khác → thôi theo dõi
      origT[inst] = nil
      return
    end
    local want = target(o)
    shownT[inst] = want
    if cur ~= want then pcall(function() inst.Text = want end) end
  end
  local function fix(inst)
    if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then return end -- [V35] IsA trực tiếp
    if origT[inst] == nil then
      local okT, txt = pcall(function() return inst.Text end)
      if not okT or not isMine(txt) then return end
      origT[inst] = txt
    end
    apply(inst)
    n = n + 1
    if not hooked[inst] then
      hooked[inst] = true
      pcall(function()
        inst:GetPropertyChangedSignal("Text"):Connect(function()
          local cur = inst.Text
          if isMine(cur) then -- Gen2 vừa ghi lại tên thật → nhớ chữ gốc rồi che lại (nếu Mask đang bật)
            origT[inst] = cur
            apply(inst)
          end
        end)
      end)
    end
  end

  -- nhãn đã nhận diện từ trước: cập nhật ngay theo Toggle (bật → che, tắt → trả lại tên thật)
  for inst in pairs(origT) do
    local okP, par = pcall(function() return inst.Parent end)
    if okP and par ~= nil then apply(inst) end
  end
  -- nhãn mới
  local okD, desc = pcall(function() return root:GetDescendants() end)
  if okD then
    for i = 1, #desc do fix(desc[i]) end
  end
  if not hooked[root] then
    hooked[root] = true
    pcall(function()
      root.DescendantAdded:Connect(function(d)
        task.defer(fix, d)
        task.delay(0.4, fix, d)
      end)
    end)
  end
  return n
end

-- name = "Default" | "Cobalt" | "Ember" | "Amethyst" | "Frost" | "Rose". "Default" = theme Liquid Glass của HiulzHub (nếu bật) hoặc "default".
_G.HzApplyTheme = function(name, save)
  if type(name) ~= "string" or name == "" then return false end
  local applied = false
  local okA, errA = pcall(function()
    local w = _G.rW15
    if not w or w.unloaded then return end
    local arg = name
    if name == "Default" and _G.HzLiquidGlassTheme then arg = _G.HzLiquidGlassTheme end
    local tries = { arg }
    if type(arg) == "string" then tries[2] = arg:lower() end
    for _, m in ipairs({ "ChangeTheme", "ModifyTheme", "SetTheme" }) do -- API Gen2 hiện dùng ChangeTheme; các tên khác là dự phòng
      local okF, f = pcall(function() return w[m] end)
      if okF and type(f) == "function" then
        for _, a in ipairs(tries) do
          local okC, res = pcall(f, w, a)
          if okC and res ~= false then applied = true break end
        end
        if applied then break end
      end
    end
  end)
  if not okA then _G.HzLogError(errA, "Theme: " .. name) end
  if save ~= false then
    pcall(function()
      local c = _G.HzCfg
      if c then
        c:Set("ui.theme", name)
        c:Flush()
      end
    end)
  end
  _G.HzThemeCur = name
  return applied
end

-- _G.HzBtnSetting = true trong lúc đổi chữ để callback của nút bỏ qua nếu handle:Set vô tình kích hoạt callback.
_G.HzSetBtnText = function(h, newText, oldText)
  if type(newText) ~= "string" then return false end
  local done = false
  _G.HzBtnSetting = true
  pcall(function()
    if type(h) == "table" then
      for _, m in ipairs({ "SetName", "SetText", "SetTitle", "Rename", "Set" }) do
        local okF, f = pcall(function() return h[m] end)
        if okF and type(f) == "function" then
          local okC = pcall(f, h, newText)
          if okC then done = true break end
        end
      end
    end
  end)
  _G.HzBtnSetting = false
  if not done and type(oldText) == "string" then
    pcall(function()
      local w = _G.rW15
      local root = w and w.screenGui
      if typeof(root) ~= "Instance" then return end
      for _, d in ipairs(root:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == oldText then
          d.Text = newText
          done = true
          break
        end
      end
    end)
  end
  return done
end

-- Vòng lặp luôn task.wait(1) từng bước, bọc pcall, lỗi ghi qua _G.HzLogError. Mặc định TẮT. Gọi _G.HzAntiAFK(true/false).
_G.HzAntiAFKOn = false
_G.HzAntiAFK = function(on)
  on = (on == true)
  _G.HzAntiAFKOn = on
  _G.HzAFKToken = (_G.HzAFKToken or 0) + 1 -- vô hiệu hoá vòng lặp cũ
  local token = _G.HzAFKToken
  if _G.HzAFKConn then
    pcall(function() _G.HzAFKConn:Disconnect() end)
    _G.HzAFKConn = nil
  end
  if not on then
    if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Anti-AFK: đã tắt", "INFO") end
    return false
  end
  local exe = _G.d8e1181c0775aa002
  local function alive()
    if token ~= _G.HzAFKToken or _G.HzAntiAFKOn ~= true or exe ~= _G.d8e1181c0775aa002 then return false end
    local w = _G.rW15
    if w and w.unloaded then return false end
    return true
  end
  local lp
  local okS, errS = pcall(function()
    lp = game:GetService("Players").LocalPlayer
  end)
  if not okS or not lp then
    _G.HzLogError(errS or "không có LocalPlayer", "Anti-AFK")
    return false
  end
  -- Di chuyển nhân vật nhẹ: hướng ngẫu nhiên 0.5 giây rồi dừng (Vector3.new(0,0,0))
  local function nudge(rng, why)
    local ok, err = pcall(function()
      local char = lp.Character
      local hum = char and char:FindFirstChildOfClass("Humanoid")
      if not hum or hum.Health <= 0 then return end -- nhân vật chết / chưa có → bỏ qua
      local ang = rng:NextNumber(0, math.pi * 2)
      hum:Move(Vector3.new(math.cos(ang), 0, math.sin(ang)), false)
      task.wait(0.5)
      pcall(function()
        hum:Move(Vector3.new(0, 0, 0), false)
      end)
    end)
    if not ok then _G.HzLogError(err, "Anti-AFK (" .. tostring(why) .. ")") end
  end
  task.spawn(function()
    local ok, err = pcall(function()
      local rng = Random.new(os.time() + math.floor(os.clock() * 1000))
      while alive() do
        local delaySec = rng:NextInteger(((_G.HzConst or {}).antiafk or {}).minDelay or 60, ((_G.HzConst or {}).antiafk or {}).maxDelay or 120) -- ngẫu nhiên
        delaySec = math.max(45, delaySec + rng:NextInteger(-15, 15)) -- [PERF] jitter ±15s
        local tStart = os.clock()
        while os.clock() - tStart < delaySec do -- [PERF] ngủ khúc ≤5s thay vì 60–120 lần task.wait(1)
          if not alive() then return end
          task.wait(math.max(0.1, math.min(5, delaySec - (os.clock() - tStart))))
        end
        if not alive() then return end
        nudge(rng, "timer")
      end
    end)
    if not ok then _G.HzLogError(err, "Anti-AFK (vòng lặp)") end
  end)
  if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Anti-AFK: đã bật (di chuyển nhân vật nhẹ nhàng, an toàn cho Anti-Cheat)", "SUCCESS") end
  return true
end

-- (Disconnect/Kick) thì chờ NGẪU NHIÊN 10–20 giây rồi TeleportService:Teleport(game.PlaceId).
-- Bộ đếm được lưu thêm vào x8k2/rejoin_state.json (nếu executor có writefile) để không mất khi sang server mới.
-- Mặc định BẬT (công tắc ở Cài đặt bật nó sau khi menu dựng xong). Toàn bộ bọc pcall, lỗi ghi qua _G.HzLogError.
_G.HzAutoRejoinOn = false
do
  local STATE_FILE = "x8k2/rejoin_state.json"
  local function stateLoad()
    local n, t = 0, 0
    pcall(function()
      if type(isfile) == "function" and type(readfile) == "function" and isfile(STATE_FILE) then
        local d = game:GetService("HttpService"):JSONDecode(readfile(STATE_FILE))
        if type(d) == "table" then
          n = tonumber(d.count) or 0
          t = tonumber(d.time) or 0
        end
      end
    end)
    -- trạng thái quá cũ (> 10 phút kể từ lần rejoin cuối) thì coi như đã ổn định → bỏ
    if n > 0 and (os.time() - t) > 600 then n = 0 end
    return n
  end
  local function stateSave()
    pcall(function()
      if type(writefile) ~= "function" then return end
      if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("x8k2") then makefolder("x8k2") end
      writefile(STATE_FILE, game:GetService("HttpService"):JSONEncode({ count = _G.HzRejoinCount or 0, time = os.time() }))
    end)
  end
  if type(_G.HzRejoinCount) ~= "number" then _G.HzRejoinCount = stateLoad() end

  _G.HzAutoRejoin = function(on)
    on = (on == true)
    _G.HzAutoRejoinOn = on
    _G.HzRejoinToken = (_G.HzRejoinToken or 0) + 1
    local token = _G.HzRejoinToken
    if type(_G.HzRejoinConns) == "table" then
      for _, c in ipairs(_G.HzRejoinConns) do pcall(function() c:Disconnect() end) end
    end
    local conns = {}
    _G.HzRejoinConns = conns
    _G.HzRejoinBusy = false
    if not on then
      if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Auto Rejoin: đã tắt", "INFO") end
      return false
    end
    local exe = _G.d8e1181c0775aa002
    local function alive()
      if token ~= _G.HzRejoinToken or _G.HzAutoRejoinOn ~= true or exe ~= _G.d8e1181c0775aa002 then return false end
      local w = _G.rW15
      if w and w.unloaded then return false end
      return true
    end
    -- Tắt hẳn Auto Rejoin (vô hiệu hoá vòng lặp + ngắt kết nối)
    local function shutOff()
      _G.HzAutoRejoinOn = false
      _G.HzRejoinToken = (_G.HzRejoinToken or 0) + 1
      for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end
    local function trigger(why)
      if not alive() or _G.HzRejoinBusy then return end
      if os.clock() - (_G.HzRejoinLast or -1000) < 30 then return end
      if (_G.HzRejoinCount or 0) >= (((_G.HzConst or {}).rejoin or {}).maxRetries or 3) then
        shutOff()
        if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Auto Rejoin: Đã thử lại 3 lần. Tự động tắt để tránh bị ban.", "ERROR") end
        pcall(function()
          if _G.rW15 and type(_G.rW15.Toast) == "function" and not _G.rW15.unloaded then
            _G.rW15:Toast("Auto Rejoin: Đã thử lại 3 lần. Tự động tắt để tránh bị ban.")
          end
        end)
        return
      end
      _G.HzRejoinBusy = true
      _G.HzRejoinLast = os.clock()
      local waitSec = math.random(10, 20) -- ngẫu nhiên 10–20 giây, không cố định
      if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Auto Rejoin: phát hiện " .. tostring(why) .. " → vào lại sau " .. tostring(waitSec) .. " giây", "WARN") end
      task.delay(waitSec, function()
        local ok, err = pcall(function()
          if not alive() then return end
          _G.HzRejoinCount = (_G.HzRejoinCount or 0) + 1 -- tăng khi thực sự gọi Teleport
          stateSave()
          local tsOk, tsErr = pcall(function()
            if _G.HzQueueHubReload then pcall(_G.HzQueueHubReload, "auto rejoin") end
            game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
          end)
          if not tsOk then _G.HzLogError(tsErr, "Auto Rejoin (Teleport)") end
          if (_G.HzRejoinCount or 0) >= (((_G.HzConst or {}).rejoin or {}).maxRetries or 3) then
            -- đã dùng hết 3 lần: tắt sau lần thử này để không lặp tiếp
            shutOff()
            if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Auto Rejoin: Đã thử lại 3 lần. Tự động tắt để tránh bị ban.", "ERROR") end
          end
        end)
        if not ok then _G.HzLogError(err, "Auto Rejoin (Teleport)") end
        task.delay(30, function() _G.HzRejoinBusy = false end)
      end)
    end
    -- Reset bộ đếm: chơi liên tục > 300 giây mà không bị đá → HzRejoinCount = 0
    task.spawn(function()
      local ok, err = pcall(function()
        for _ = 1, (((_G.HzConst or {}).rejoin or {}).stableSeconds or 300) do
          if not alive() then return end
          task.wait(1)
        end
        if alive() and (_G.HzRejoinCount or 0) ~= 0 then
          _G.HzRejoinCount = 0
          stateSave()
          if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Auto Rejoin: đã chơi ổn định > 5 phút → đặt lại bộ đếm", "INFO") end
        end
      end)
      if not ok then _G.HzLogError(err, "Auto Rejoin (reset bộ đếm)") end
    end)
    task.spawn(function()
      local ok, err = pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local overlay
        for _ = 1, 30 do -- chờ tối đa ~30 giây cho RobloxPromptGui xuất hiện (mỗi bước task.wait(1))
          if not alive() then return end
          local g = CoreGui:FindFirstChild("RobloxPromptGui")
          overlay = g and g:FindFirstChild("promptOverlay")
          if overlay then break end
          task.wait(1)
        end
        if not overlay then error("không thấy CoreGui.RobloxPromptGui.promptOverlay", 0) end
        local c = overlay.ChildAdded:Connect(function(child)
          local ok2, err2 = pcall(function()
            if child.Name == "ErrorPrompt" then trigger("ErrorPrompt") end
          end)
          if not ok2 then _G.HzLogError(err2, "Auto Rejoin (ChildAdded)") end
        end)
        if alive() then conns[#conns + 1] = c else c:Disconnect() end
      end)
      if not ok then _G.HzLogError(err, "Auto Rejoin (khởi tạo)") end
    end)
    if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "Auto Rejoin: đã bật (10–20 giây ngẫu nhiên, tối đa 3 lần)", "SUCCESS") end
    return true
  end
end

----------------------------------------------------------------
-- LOGIC HỆ THỐNG RAYFIELD (ĐÃ SỬA LINK & LOGIC GAME)
----------------------------------------------------------------
local function StartRayfield()
  if currentExecute ~= _G.d8e1181c0775aa002 then return end -- [FIX RACE]
  if _G.HzPerf then _G.HzPerf("Bắt đầu StartRayfield") end
  local PlaceID = tonumber(game.PlaceId) or 0
  local UniverseID = tonumber(game.GameId) or 0
  local GameName
  GameName = _G.HzFetchGameName(PlaceID, 1.2, function(name)
    if currentExecute ~= _G.d8e1181c0775aa002 then return end
    GameName = name
    pcall(function()
      local w = _G.rW15
      if w and not w.unloaded and type(w.SetSubtitle) == "function" then w:SetSubtitle(name) end
    end)
  end)

  local HzG = _G.HzDetectGame(PlaceID, UniverseID, GameName)

-- [RAYFIELD GEN2] Tải thư viện mới
local Rayfield
do
  local okRF, lib = false, nil
  local gsrc = _G.HzGetGen2Src and _G.HzGetGen2Src(false)
  if gsrc then okRF, lib = pcall(function() return loadstring(gsrc)() end) end
  if not okRF or not (type(lib) == "table" and lib.CreateWindow ~= nil) then
    okRF, lib = pcall(function()
      local fresh = _G.HzGetGen2Src and _G.HzGetGen2Src(true) or game:HttpGet("https://sirius.menu/gen2")
      return loadstring(fresh)()
    end)
  end
  if not okRF or not (type(lib) == "table" and lib.CreateWindow ~= nil) then
    if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Lỗi tải Rayfield Gen2: " .. tostring(lib), "ERROR") end
    pcall(function()
      game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = _G.tR9("Lỗi"), Text = _G.tR9("Thư viện GUI (Rayfield Gen2) không tải được. Dừng script."), Duration = 6
      })
    end)
    return
  end
  Rayfield = lib
end
_G.rF14 = Rayfield
if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Tải thành công Rayfield Gen2", "SUCCESS") end
if _G.HzPerf then _G.HzPerf("Rayfield Gen2 sẵn sàng") end

_G.HzLiquidGlassTheme = (function()
  if _G.HzGlassUI == false or _G.HzPerfLvl == "low" then return nil end -- [PERF] LOW: theme "default" (không Liquid Glass)
  local C3, CS = Color3.fromRGB, ColorSequence.new
  local white, cyan = C3(255, 255, 255), C3(0, 230, 255)
  return {
    -- Khung & hình dạng
    CornerRoundness = UDim.new(0, 28),
    ElementCornerRadius = UDim.new(0, 18),
    PillCornerRadius = UDim.new(0, 22),
    WindowColor = CS(C3(18, 32, 54), C3(8, 14, 28)),
    ShadowColor = C3(0, 0, 0),
    LiveAnimation = (_G.HzPerfLvl == "high"), -- [PERF] gradient cửa sổ trôi: chỉ HIGH (MED/LOW tắt)
    SurfaceStroke = C3(200, 240, 255),     -- viền sáng quanh cửa sổ/popup
    -- Chữ
    TitlingColor = white,
    ContentColor = C3(240, 248, 255),
    ElementTextHoverColor = white,
    ActionColor = C3(200, 235, 255),
    -- Tab
    TabColor = white,
    TabBackground = CS(C3(0, 150, 190), C3(0, 105, 160)),
    TabStroke = CS(C3(160, 240, 255), C3(0, 190, 230)),
    -- Element: kính trong (fill trắng, rất trong suốt) + viền sáng
    ElementGradient = CS(white, C3(200, 225, 245)),
    ElementTransparency = 0.84,
    ElementStroke = white,
    ElementStrokeGradient = CS(white, C3(150, 235, 255)),
    ElementStrokeTransparency = 0.72,
    ElementStrokeHover = cyan,
    ElementStrokeHoverTransparency = 0.3,
    StatBackground = C3(24, 40, 64),
    -- Điều khiển
    AccentColor = cyan,
    AccentStroke = cyan,
    AccentGlow = 0.55,
    SliderBackground = C3(30, 48, 72),
    SliderBackgroundHover = C3(40, 64, 92),
    SliderProgress = CS(cyan, C3(90, 180, 255)),
    SliderStroke = C3(150, 230, 255),
    SliderHandle = white,
    ToggleTrack = white,
    ToggleTrackTransparency = 0.78,
    ToggleKnobOff = C3(235, 245, 255),
    ToggleKnobOffTransparency = 0.15,
    DarkToggleOverlay = false,
    DropdownHighlight = C3(0, 200, 235),
    -- Ô nhập & nút
    FieldBackground = white,
    FieldTransparency = 0.86,
    FieldGlow = cyan,
    PlaceholderColor = C3(150, 175, 195),
    NeutralButton = C3(60, 84, 112),
    NeutralButtonHover = C3(80, 108, 140),
    NeutralButtonStroke = C3(150, 220, 255),
    ErrorColor = C3(255, 90, 110),
    ErrorStrokeColor = C3(255, 150, 160),
  }
end)()

local GenWindow
do
  local defaultTheme = _G.HzLiquidGlassTheme or "default"
  local theme = defaultTheme
  pcall(function()
    local saved = _G.HzCfg and _G.HzCfg:Get("ui.theme", nil)
    if type(saved) == "string" and saved ~= "" and saved ~= "Default" then theme = saved end
  end)
  local props = {
  name = "HiulzHub",
  subtitle = (GameName or "Main Menu"),
  icon = tonumber("131699875210935"),
  sidebarLayout = true,
  theme = theme,
  showName = "HiulzHub",
  showIcon = (_G.HzPerfLvl ~= "low") and tonumber("131699875210935") or nil, -- [PERF] LOW: tắt showIcon
  -- [GEN2 LOCALIZATION] https://docs.sirius.menu/rayfield-gen2/localization
  locale = _G.lG10(),
  translations = _G.tP18(),
  translator = _G.tT19,
  configuration = {
    autoSave = true,
    autoLoad = true,
    fileName = "Main",
    customFolder = "x8k2",
  },
  }
  local okW, w = pcall(function() return Rayfield:CreateWindow(props) end)
  if not okW or w == nil then
    if theme ~= defaultTheme then -- theme đã lưu bị lỗi → thử lại với theme mặc định
      props.theme = defaultTheme
      w = Rayfield:CreateWindow(props)
    else
      error(w, 0)
    end
  end
  GenWindow = w
end
-- [FIX RACE] CreateWindow yield — exec mới hơn có thể đã bắt đầu trong lúc đó
if currentExecute ~= _G.d8e1181c0775aa002 then
  pcall(function()
    if GenWindow then
      if type(GenWindow.Unload) == "function" then GenWindow:Unload() end
      if type(GenWindow.Close)  == "function" then GenWindow:Close()  end
      if GenWindow.screenGui and GenWindow.screenGui.Destroy then
        GenWindow.screenGui:Destroy()
      end
    end
  end)
  return
end
_G.rW15 = GenWindow
_G.HzConfirm = function(title, content, okText, onYes)
  local win = _G.rW15
  local T = _G.gL22 and function(x) return x end or _G.tR9
  local shown = false
  if win and type(win.Popup) == "function" and not win.unloaded then
    shown = pcall(function()
      win:Popup({
        title = T(title), content = T(content),
        options = {
          { text = T("Hủy"), style = "neutral" },
          { text = T(okText), style = "danger", callback = function() task.defer(function() pcall(onYes) end) end },
        },
        dismissable = true,
      })
    end)
  end
  if not shown then onYes() end
end
pcall(function()
  local s = _G.HzCfg and _G.HzCfg:Get("ui.theme", nil)
  _G.HzThemeCur = (type(s) == "string" and s ~= "") and s or "Default"
  if _G.HzThemeCur ~= "Default" then
    task.delay(0.5, function()
      if currentExecute == _G.d8e1181c0775aa002 then pcall(_G.HzApplyTheme, _G.HzThemeCur, false) end
    end)
  end
end)
pcall(_G.HzPatchRayfieldName, GenWindow.screenGui)
task.delay(1.5, function() -- [V35] bỏ 0.4/4/10s; DescendantAdded trong hàm đã bắt nhãn dựng trễ
  local w = _G.rW15
  if w and not w.unloaded then pcall(_G.HzPatchRayfieldName, w.screenGui) end
end)
pcall(function()
  local a = _G.HzGlassWindowAlpha
  if type(a) == "number" and GenWindow and typeof(GenWindow.main) == "Instance" and GenWindow.main:IsA("GuiObject") then
    GenWindow.main.BackgroundTransparency = math.clamp(a, 0, 0.9)
  end
end)

-- Giữ nút thu gọn (HiulzHub - Tap to show) luôn nằm trong màn hình khi kéo.
pcall(function()
  local main, sg = GenWindow.main, GenWindow.screenGui
  if typeof(main) ~= "Instance" or typeof(sg) ~= "Instance" then return end
  local busy = false
  local function clampPill()
    if busy or not main.Parent then return end
    if not GenWindow.hidden or GenWindow.animating then return end -- chỉ khi đang thu gọn và không đang chạy hiệu ứng
    local vp, sz, ap, pos = sg.AbsoluteSize, main.AbsoluteSize, main.AnchorPoint, main.Position
    if vp.X <= 0 or vp.Y <= 0 or sz.X <= 0 or sz.Y <= 0 then return end
    local left = pos.X.Scale * vp.X + pos.X.Offset - ap.X * sz.X
    local top = pos.Y.Scale * vp.Y + pos.Y.Offset - ap.Y * sz.Y
    local cl = math.clamp(left, 0, math.max(0, vp.X - sz.X))
    local ct = math.clamp(top, 0, math.max(0, vp.Y - sz.Y))
    if cl == left and ct == top then return end
    busy = true
    main.Position = UDim2.new(pos.X.Scale, pos.X.Offset + (cl - left), pos.Y.Scale, pos.Y.Offset + (ct - top))
    busy = false
  end
  main:GetPropertyChangedSignal("Position"):Connect(clampPill)
  sg:GetPropertyChangedSignal("AbsoluteSize"):Connect(clampPill)
end)

-- [PC SUPPORT] Hỗ trợ client máy tính (Windows/Mac):
--   * Phím tắt RightShift: ẩn/hiện toàn bộ menu (không cần bấm nút thu gọn bằng chuột).
--   * Không kích hoạt khi đang gõ chữ trong ô nhập (TextBox) hay khi game đang chiếm phím.
--   * Tự ngắt phím tắt khi menu bị gỡ (Đóng toàn bộ) hoặc khi execute lại script.
--   * Cờ _G.HzIsDesktop = true khi có bàn phím + chuột (dùng cho các module khác nếu cần).
do
  local UIS = game:GetService("UserInputService")
  local isDesktop = false
  pcall(function() isDesktop = UIS.KeyboardEnabled and UIS.MouseEnabled end)
  _G.HzIsDesktop = isDesktop

  --   _G.HzToggleKey = ẩn/hiện menu (mặc định RightShift) | _G.HzMusicKey = bật/tắt nhạc (mặc định M)
  _G.HzToggleKey = Enum.KeyCode.RightShift
  _G.HzMusicKey = Enum.KeyCode.M
  _G.HzKeyOf = function(v) -- EnumItem | tên phím ("M", "RightShift", "MouseButton2"...) -> EnumItem | nil
    if typeof(v) == "EnumItem" then return v end
    if type(v) == "string" and v ~= "" then
      local ok, kc = pcall(function() return Enum.KeyCode[v] end)
      if ok and kc then return kc end
      local ok2, ut = pcall(function() return Enum.UserInputType[v] end)
      if ok2 and ut then return ut end
    end
    return nil
  end
  if _G.HzPcToggleConn then pcall(function() _G.HzPcToggleConn:Disconnect() end) end
  local conn
  conn = UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    local kc, ut = input.KeyCode, input.UserInputType
    local tk, mk = _G.HzToggleKey, _G.HzMusicKey
    local isT = tk ~= nil and (kc == tk or ut == tk)
    local isM = mk ~= nil and (kc == mk or ut == mk)
    if not isT and not isM then return end
    if UIS:GetFocusedTextBox() then return end
    if isT then
      local sg = GenWindow.screenGui
      if typeof(sg) ~= "Instance" or not sg.Parent then
        if conn then conn:Disconnect() end
        return
      end
      sg.Enabled = not sg.Enabled
    elseif type(_G.HzToggleMusic) == "function" then
      pcall(_G.HzToggleMusic)
    end
  end)
  _G.HzPcToggleConn = conn

  if isDesktop then
    task.delay(8, function()
      pcall(function()
        local l = "vi"
        if type(_G.lG10) == "function" then l = tostring(_G.lG10()):lower():sub(1, 2) end
        local tkn = (typeof(_G.HzToggleKey) == "EnumItem") and _G.HzToggleKey.Name or "RightShift"
        GenWindow:Notify({
          title = "💻 PC",
          content = (l == "en" and ("Press " .. tkn .. " to show/hide the menu."))
            or (l == "pt" and ("Pressione " .. tkn .. " para mostrar/ocultar o menu."))
            or ("Nhấn " .. tkn .. " để ẩn/hiện menu."),
          duration = 6,
        })
      end)
    end)
  end
end

do
  local ok = false
  pcall(function()
    ok = type(GenWindow.SetLocale) == "function"
      and type(GenWindow.SetTranslator) == "function"
      and type(GenWindow.RegisterTranslations) == "function"
  end)
  _G.gL22 = ok

  local function applyLocale(lang)
    lang = tostring(lang or "vi"):lower():sub(1, 2)
    for _, c in ipairs((lang == "pt" and { "pt", "pt-BR" }) or (lang == "en" and { "en", "en-US" }) or { lang }) do
      local got
      pcall(function() GenWindow:SetLocale(c) got = GenWindow:GetLocale() end)
      if type(got) ~= "string" or got == "" or got:lower():sub(1, 2) == lang then return end
    end
  end

  if ok then
    pcall(function() GenWindow:SetTranslator(_G.tT19) end)
    applyLocale(_G.lG10())
    _G.oL16(function(newLang) applyLocale(newLang) end)
    _G.hX20(function(map, mapPt)
      pcall(function() GenWindow:RegisterTranslations({ en = map }) end)
      if mapPt then pcall(function() GenWindow:RegisterTranslations({ pt = mapPt }) end) end
    end)
    if _G.aa3542001e064bc52 then
      _G.aa3542001e064bc52(string.format(_G.tR9("Localization Gen2: BẬT (locale = %s) — đổi ngôn ngữ trực tiếp"), tostring(_G.lG10())), "SUCCESS")
    end
  else
    -- Chế độ cũ (v18): dịch chuỗi lúc dựng UI + bọc Notify
    pcall(function()
      local rawNotify = GenWindow.Notify
      if type(rawNotify) == "function" then
        GenWindow.Notify = function(self, props)
          if type(props) == "table" then
            props.title = _G.tR9(props.title)
            props.content = _G.tR9(props.content)
          end
          return rawNotify(self, props)
        end
      end
    end)
    if _G.aa3542001e064bc52 then
      _G.aa3542001e064bc52("Localization Gen2 không khả dụng — dùng dịch lúc dựng UI (chế độ cũ).", "WARN")
    end
  end
end
pcall(function()
  local rawN = GenWindow.Notify
  if type(rawN) == "function" then
    GenWindow.Notify = function(self, props)
      if type(props) == "table" then
        if type(props.title) == "string" then props.title = _G.tR9(props.title) end
        if type(props.content) == "string" then props.content = _G.tR9(props.content) end
      end
      return rawN(self, props)
    end
  end
end)

pcall(function()
  local rawT = GenWindow.Toast
  if type(rawT) == "function" then
    GenWindow.Toast = function(self, props)
      if type(props) == "table" then
        if props.content ~= nil and props.subtitle == nil then props.subtitle = props.content end
        props.content = nil
        if type(props.title) == "string" then props.title = _G.tR9(props.title) end
        if type(props.subtitle) == "string" then props.subtitle = _G.tR9(props.subtitle) end
      end
      return rawT(self, props)
    end
  end
end)

HzUiLang = function()
  local l
  if _G.gL22 then pcall(function() l = GenWindow:GetLocale() end) end
  l = type(l) == "string" and l:lower():sub(1, 2) or nil
  if l ~= "vi" and l ~= "en" and l ~= "pt" then
    l = "vi"
    pcall(function() l = tostring(_G.lG10()):lower():sub(1, 2) end)
  end
  return l
end
HzUiL = function(s)
  if _G.gL22 then return s end
  return _G.tR9(s)
end
HzUiS = function(s)
  if type(s) ~= "string" or s == "" then return s end
  if not _G.gL22 then return _G.tR9(s) end
  local out
  pcall(function() out = _G.tT19(s, HzUiLang()) end)
  return out or s
end
HzFmtN = function(v, _, mx) return string.format("%d/%d", math.floor((v or 0) + 0.5), math.floor((mx or 0) + 0.5)) end

-- Bản Gen2 không có SetProfile -> bỏ qua êm (pcall).
HzSetProfile = function(text)
  pcall(function()
    local w = _G.rW15
    if w and type(w.SetProfile) == "function" and not w.unloaded then
      w:SetProfile(text and tostring(text) or nil)
    end
  end)
end
HzSetProfile("V41 AutoLoad")
pcall(function() GenWindow:CreateTag({ text = "BETA", color = Color3.fromRGB(255, 175, 15) }) end)

-- Lớp tương thích: giữ nguyên cú pháp cũ (Name/Callback/CurrentValue...) và dịch sang API Gen2.
-- Chỉ các phần tử có `Save = true` mới được lưu cấu hình; còn lại forgetState = true
-- (tránh autoLoad tự phát nhạc / tự chạy script khi mở lại menu).
local Window = (function()
local L = HzUiL
local Window = { Handle = GenWindow }
local TabProxy = {}
TabProxy.__index = TabProxy

local function pick(p, ...)
  for _, k in ipairs({...}) do
    if p[k] ~= nil then return p[k] end
  end
  return nil
end

local function wrapCallback(cb, convert)
  if type(cb) ~= "function" then return nil end
  return function(...)
    local args = table.pack(...)
    if convert then args = table.pack(convert(table.unpack(args, 1, args.n))) end
    local ok, err = pcall(cb, table.unpack(args, 1, args.n))
    if not ok and _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Callback lỗi: " .. tostring(err), "ERROR") end
  end
end

function TabProxy:_track(kind, name, handle)
  table.insert(self._order, { kind = kind, name = tostring(name or ""), handle = handle })
  return handle
end

function TabProxy:CreateSection(arg)
  local name = type(arg) == "table" and pick(arg, "Name", "name") or arg
  return self:_track("section", name, self.Raw:CreateSection({ name = L(tostring(name)) }))
end

function TabProxy:CreateLabel(arg)
  local text = type(arg) == "table" and pick(arg, "Text", "text", "Name", "name") or arg
  return self:_track("label", text, self.Raw:CreateText({ text = L(tostring(text)) }))
end
TabProxy.CreateParagraph = function(self, p)
  return self:_track("label", pick(p, "Title", "Name"), self.Raw:CreateText({
    name = L(pick(p, "Title", "Name", "title", "name")),
    text = L(pick(p, "Content", "Text", "content", "text")),
  }))
end

function TabProxy:CreateButton(p)
  local name = L(pick(p, "Name", "name"))
  return self:_track("button", name, self.Raw:CreateButton({
    name = name,
    description = L(pick(p, "Description", "description")),
    icon = pick(p, "Icon", "icon"),
    callback = (function() -- [V35] B7
      local cb = wrapCallback(pick(p, "Callback", "callback"))
      if not cb then return nil end
      return function(...) _G.HzClickSfx(0.3); return cb(...) end
    end)(),
  }))
end

function TabProxy:CreateToggle(p)
  local name = L(pick(p, "Name", "name"))
  return self:_track("toggle", name, self.Raw:CreateToggle({
    name = name,
    icon = pick(p, "Icon", "icon"),
    value = pick(p, "CurrentValue", "value") == true,
    flag = pick(p, "Flag", "flag"),
    forgetState = not p.Save,
    callback = (function() -- [V35] B7
      local cb = wrapCallback(pick(p, "Callback", "callback"))
      if not cb then return nil end
      return function(...) _G.HzClickSfx(0.3); return cb(...) end
    end)(),
  }))
end

function TabProxy:CreateSlider(p)
  local name = L(pick(p, "Name", "name"))
  return self:_track("slider", name, self.Raw:CreateSlider({
    name = name,
    range = pick(p, "Range", "range"),
    increment = pick(p, "Increment", "increment"),
    value = pick(p, "CurrentValue", "value"),
    suffix = pick(p, "Suffix", "suffix"),
    flag = pick(p, "Flag", "flag"),
    forgetState = not p.Save,
    callback = wrapCallback(pick(p, "Callback", "callback")),
  }))
end

function TabProxy:CreateDropdown(p)
  local name = L(pick(p, "Name", "name"))
  local options = pick(p, "Options", "options") or {}
  local multi = pick(p, "MultipleOptions", "multiSelect") == true
  local cur = pick(p, "CurrentOption", "value")
  -- Gen2: callback đơn chọn trả về chuỗi; code cũ mong đợi bảng -> chuẩn hoá lại thành bảng
  local function back(v)
    if type(v) ~= "string" or table.find(options, v) then return v end
    for _, o in ipairs(options) do
      if _G.tR9(o) == v then return o end
    end
    return v
  end
  local function toTable(sel)
    if type(sel) == "table" then
      local out = {}
      for k, v in pairs(sel) do out[k] = back(v) end
      return out
    end
    if sel == nil then return {} end
    return { back(sel) }
  end
  local initial
  if type(cur) == "table" then
    local valid = {}
    for _, v in ipairs(cur) do
      if table.find(options, v) then table.insert(valid, v) end
    end
    if multi then initial = valid else initial = valid[1] end
  elseif type(cur) == "string" and table.find(options, cur) then
    initial = cur
  end
  local placeholder = L((type(cur) == "table" and cur[1]) or (type(cur) == "string" and cur) or nil)
  return self:_track("dropdown", name, self.Raw:CreateDropdown({
    name = name,
    options = options,
    value = initial,
    multiSelect = multi,
    placeholder = placeholder,
    flag = pick(p, "Flag", "flag"),
    forgetState = not p.Save,
    callback = wrapCallback(pick(p, "Callback", "callback"), toTable),
  }))
end

function TabProxy:CreateInput(p)
  local name = L(pick(p, "Name", "name"))
  local clearAfter = pick(p, "RemoveTextAfterFocusLost", "removeTextAfterFocusLost") == true
  local cb = wrapCallback(pick(p, "Callback", "callback"))
  local h
  if clearAfter and cb then
    local base = cb
    cb = function(...)
      base(...)
      task.defer(function() pcall(function() if h and h.Set then h:Set("", true) end end) end)
    end
  end
  h = self.Raw:CreateInput({
    name = name,
    placeholder = L(pick(p, "PlaceholderText", "placeholder")),
    value = pick(p, "CurrentValue", "value"),
    flag = pick(p, "Flag", "flag"),
    forgetState = not p.Save,
    callback = cb,
  })
  return self:_track("input", name, h)
end

function TabProxy:CreateColorPicker(p)
  local name = L(pick(p, "Name", "name"))
  return self:_track("color", name, self.Raw:CreateColorPicker({
    name = name,
    color = pick(p, "Color", "color"),
    flag = pick(p, "Flag", "flag"),
    forgetState = not p.Save,
    callback = wrapCallback(pick(p, "Callback", "callback")),
  }))
end

function TabProxy:CreateConsole(p)
  local name = L(pick(p, "Name", "name"))
  return self:_track("console", name, self.Raw:CreateConsole({
    name = name,
    text = pick(p, "Text", "text"),
    height = pick(p, "Height", "height"),
    follow = pick(p, "Follow", "follow"),
    maxLines = pick(p, "MaxLines", "maxLines"),
  }))
end

local function nullHandle()
  return setmetatable({ value = 0, text = "" }, { __index = function() return function() return 0 end end })
end

local function rawElement(self, kind, p, dflt)
  local props = {}
  for k, v in pairs(type(p) == "table" and p or { [dflt] = p }) do props[k] = v end
  for _, k in ipairs({ "name", "description", "text" }) do
    if type(props[k]) == "string" then props[k] = L(props[k]) end
  end
  local ok, h = pcall(function() return self.Raw["Create" .. kind](self.Raw, props) end)
  if not ok or type(h) ~= "table" then h = nullHandle() end
  return self:_track(string.lower(kind), props.name or props.text or "", h)
end

function TabProxy:CreateDivider(p) return rawElement(self, "Divider", p, "text") end
function TabProxy:CreateProgress(p) return rawElement(self, "Progress", p, "name") end

-- Nhận cả kiểu viết cũ (Name/Description/Value/Flag/Save/Callback/OnChanged). Gen2 thiếu element -> handle rỗng.
function TabProxy:CreateKeybind(p)
  p = type(p) == "table" and p or {}
  local desc = pick(p, "Description", "description")
  local props = {
    name = L(tostring(pick(p, "Name", "name") or "")),
    description = type(desc) == "string" and L(desc) or nil,
    icon = pick(p, "Icon", "icon"),
    value = pick(p, "Value", "value", "CurrentKeybind"),
    flag = pick(p, "Flag", "flag"),
    forgetState = not (p.Save or p.save),
    callback = wrapCallback(pick(p, "Callback", "callback")),
    onChanged = wrapCallback(pick(p, "OnChanged", "onChanged")),
  }
  local ok, h = pcall(function() return self.Raw:CreateKeybind(props) end)
  if not ok or type(h) ~= "table" then h = nullHandle() end
  return self:_track("keybind", props.name, h)
end

function Window:CreateTab(nameOrProps, icon)
  local props
  if type(nameOrProps) == "table" then
    props = nameOrProps
  else
    props = { name = nameOrProps, icon = icon }
  end
  local raw = GenWindow:CreateTab({
    name = L(pick(props, "Name", "name")),
    icon = pick(props, "Icon", "icon"),
  })
  return setmetatable({ Raw = raw, _order = {} }, TabProxy)
end

-- Khôi phục thứ tự gốc của tab (dùng cho ô tìm kiếm)
function TabProxy:RestoreOrder()
  for i = #self._order, 1, -1 do
    pcall(function() self._order[i].handle:MoveToTop() end)
  end
end
return Window
end)()
PlaySound("95148743653937")

local StarterGui = game:GetService("StarterGui")

local function RobloxNotify(title, text, duration)
  duration = duration or 5
  pcall(function()
    StarterGui:SetCore("SendNotification", {
      Title = _G.tR9(tostring(title or "HiulzHub")),
      Text = _G.tR9(tostring(text or "")),
      Duration = tonumber(duration) or 5
    })
  end)
end

task.delay(0.6, function()
  pcall(function()
    local okToast = false
    local w = _G.rW15
    if w and type(w.Toast) == "function" and not w.unloaded then
      okToast = pcall(function()
        w:Toast({ title = "✅ " .. _G.tR9("Menu đã tải xong"), subtitle = _G.tR9("Sẵn sàng sử dụng!"), duration = 4 })
      end)
    end
    if not okToast then
      RobloxNotify("✅", "Menu đã tải xong — sẵn sàng sử dụng!", 6)
    end
  end)
end)

task.spawn(function()
  pcall(function()
    if LoadingGui and LoadingGui.Parent then
      pcall(function()
        if LoadingGui:FindFirstChild("Overlay") and LoadingGui.Overlay:IsA("Frame") then
          local ok, tween = pcall(function()
            return game:GetService("TweenService"):Create(LoadingGui.Overlay, TweenInfo.new(0.35), {BackgroundTransparency = 1})
          end)
          if ok and tween then
            tween:Play()
            tween.Completed:Wait()
          end
        end
      end)
      pcall(function() LoadingGui:Destroy() end)
    end
  end)
end)

        local function Notify(title, content)
    local decalID = tonumber("11630044194")
    if string.find(string.lower(content), "load script") then
      decalID = tonumber("17223303970")
    end
    local shownToast = false
    if type(GenWindow.Toast) == "function" and #tostring(content) <= 48 and #tostring(title) <= 24
      and not string.find(string.lower(tostring(content)), "load script") then
      shownToast = pcall(function()
        GenWindow:Toast({ title = tostring(title), subtitle = tostring(content), duration = 3 })
      end)
    end
    if not shownToast then
      pcall(function() GenWindow:Notify({ title = _G.tR9(tostring(title)), content = _G.tR9(tostring(content)), duration = 4, icon = decalID }) end)
    end

    -- [NÂNG CẤP]: Tự động đẩy mọi thông báo vào Nhật Ký Hệ Thống
    if _G.aa3542001e064bc52 then
      local logType = "INFO"
      local lowerContent = string.lower(content)

      -- Phân loại Log tự động dựa trên từ khóa trong thông báo
      if string.find(lowerContent, "lỗi") or string.find(lowerContent, "thất bại") or string.find(lowerContent, "không thể") or string.find(lowerContent, "❌") or string.find(lowerContent, "error") or string.find(lowerContent, "failed") or string.find(lowerContent, "cannot") or string.find(lowerContent, "could not") then
        logType = "ERROR"
      elseif string.find(lowerContent, "cảnh báo") or string.find(lowerContent, "hết lượt") or string.find(lowerContent, "đã tắt") or string.find(lowerContent, "warning") or string.find(lowerContent, "limit reached") or string.find(lowerContent, "disabled") then
        logType = "WARN"
      elseif string.find(lowerContent, "thành công") or string.find(lowerContent, "đã bật") or string.find(lowerContent, "hoàn thành") or string.find(lowerContent, "✅") or string.find(lowerContent, "success") or string.find(lowerContent, "enabled") or string.find(lowerContent, "completed") then
        logType = "SUCCESS"
      end

      _G.aa3542001e064bc52(_G.tR9(tostring(title)) .. " - " .. _G.tR9(tostring(content)), logType)
    end
  end

_G.e37669d62d5f58e0d = _G.e37669d62d5f58e0d or 0

if type(Notify) ~= "function" then
  Notify = function(title, msg)
    pcall(function() print(("Notify - %s: %s"):format(tostring(title), tostring(msg))) end)
  end
end

if type(NotifySafe) ~= "function" then
  NotifySafe = function(title, msg)
    pcall(function() print(("NotifySafe - %s: %s"):format(tostring(title), tostring(msg))) end)
  end
end

-- [V22] Helper dùng chung (gán global như NotifySafe để không tăng số local của chunk)
-- Luôn ghi đè (không dùng "if type ~= function") để bản execute lại trỏ đúng Notify mới.
SafeNotify = function(title, msg)
  return (pcall(Notify, title, msg))
end

-- [V25] Tự copy link Discord vào bộ nhớ tạm khi script khởi động xong (đặt false để tắt)
task.delay(1.5, function()
  pcall(function()
    local AUTO_COPY_DISCORD = true
    if not AUTO_COPY_DISCORD then return end
    local okCopy = false
    if type(setclipboard) == "function" then
      okCopy = (pcall(setclipboard, "https://discord.gg/UcFrgBPZbZ"))
    end
    if okCopy then
      SafeNotify("Discord", "Đã copy link Discord!")
    elseif _G.aa3542001e064bc52 then
      _G.aa3542001e064bc52("Executor không hỗ trợ copy.", "WARN")
    end
  end)
end)

HzTrack = function(conn)
  if type(_G._connections) ~= "table" then _G._connections = {} end
  if conn then _G._connections[conn] = true end -- [V35] hash: không trùng
  return conn
end

HzPostJson = function(url, headers, body)
  local req = (syn and syn.request) or (http and http.request) or request
    or (fluxus and fluxus.request) or http_request
  if type(req) ~= "function" then return false, "executor không hỗ trợ request" end
  local ok, res = pcall(req, { Url = url, Method = "POST", Headers = headers, Body = body })
  if not ok then return false, tostring(res) end
  if type(res) ~= "table" then return true end
  local code = tonumber(res.StatusCode or res.statusCode or res.Status)
  if code then return (code >= 200 and code < 300), "HTTP " .. code end
  if res.Success ~= nil then return res.Success == true, "Success=false" end
  return true
end

if type(CopyToClipboardSafe) ~= "function" then
  CopyToClipboardSafe = function(text)
    local ok, err = pcall(function()
      if setclipboard then
        setclipboard(text)
        return true
      else
        print("Clipboard fallback. Please copy manually:\n" .. tostring(text))
        return false
      end
    end)
    if not ok then
      print("CopyToClipboardSafe error:", err)
      return false
    end
    return true
  end
end

if type(safeLoad) ~= "function" then
  safeLoad = function(name, url)
    if _G.f8eefa956e6130f83 then
      if _G.e37669d62d5f58e0d >= 3 then
        SafeNotify(name, "❌ Đã hết lượt copy (Tối đa 3 lần)!")
        return false
      end

      local codeToCopy = 'loadstring(game:HttpGet("' .. url .. '"))()'
      local ok = pcall(function()
        if setclipboard then setclipboard(codeToCopy) end
      end)

      if ok then
        _G.e37669d62d5f58e0d = _G.e37669d62d5f58e0d + 1
        SafeNotify(name, "✅ Đã copy script vào clipboard!\n(" .. _G.e37669d62d5f58e0d .. "/3)")
        if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Copy script: " .. name, "SUCCESS") end
      else
        SafeNotify(name, "❌ Executor không hỗ trợ copy!")
      end
      return true
    end

    SafeNotify(name, "Đang tải, chờ chút...")

    local ok, result = pcall(function()
      local code = game:HttpGet(url, true)
      if code == "404: Not Found" or code == "Not Found" or string.find(code, "404 Not Found") or string.find(code, "400: Invalid Request") then
        return "DEAD_SCRIPT"
      end

      if code then
        local fn = loadstring(code)
        if fn then
          fn()
          return "SUCCESS"
        else
          return "SYNTAX_ERROR"
        end
      end
      return "NO_CODE"
    end)

    if not ok then
      if tostring(result):find("404") or tostring(result):find("Not Found") then
        SafeNotify(name, "❌ Script này đã bị xóa bởi tác giả!")
        if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Lỗi tải 404: " .. name, "ERROR") end
        _G.HzLogError("404 / Not Found: " .. tostring(result), name)
      else
        _G.HzLogError(result, name)
        SafeNotify(name, "Quá trình tải thất bại... "..tostring(result))
        if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Lỗi thực thi: " .. name .. " - " .. tostring(result), "ERROR") end
      end
      return nil
    elseif result == "DEAD_SCRIPT" then
      SafeNotify(name, "❌ Script này đã bị xóa bởi tác giả!")
      if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Chặn Script Chết: " .. name, "WARN") end
      _G.HzLogError("Script chết (404/Not Found)", name)
      return nil
    elseif result == "SYNTAX_ERROR" then
      SafeNotify(name, "❌ Script bị lỗi cú pháp, không thể chạy!")
      if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Lỗi Cú Pháp Script: " .. name, "ERROR") end
      _G.HzLogError("Lỗi cú pháp (loadstring trả về nil)", name)
      return nil
    end

    SafeNotify(name, "✅ Quá trình tải thành công!")
    if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Tải & Chạy thành công: " .. name, "SUCCESS") end
    return true
  end
end

-- ===== START: Smart LowMode & Safe loader wrapper =====

_G.lM4 = _G.lM4 or false
_G.cF2 = 60
_G.cP3 = 50

task.spawn(function()
  local frames = 0
  local lastUpdate = tick()
  HzTrack(RunService.Heartbeat:Connect(function()
    frames = frames + 1
    local now = tick()
    if now - lastUpdate >= 1 then
      _G.cF2 = frames
      frames = 0
      lastUpdate = now
      pcall(function()
        local stats = game:GetService("Stats")
        local net = stats:FindFirstChild("Network")
        if net then
          local serverStats = net:FindFirstChild("ServerStatsItem")
          if serverStats and serverStats:FindFirstChild("Data Ping") then
            _G.cP3 = serverStats["Data Ping"]:GetValue()
            return
          end
        end

        if Players.LocalPlayer and type(Players.LocalPlayer.GetNetworkPing) == "function" then
          _G.cP3 = Players.LocalPlayer:GetNetworkPing() * 1000
        end
      end)
    end
  end))
end)

local function detectSlowNetOrWeakDevice()
  local isWeakDevice = (_G.cF2 < 15)
  local isSlowNetwork = (_G.cP3 > 300)
  return (isWeakDevice or isSlowNetwork), _G.cF2, _G.cP3
end

local function enableLowMode(reason)
  if _G.lM4 then return end
  _G.lM4 = true
  _G.lG5 = true
  getgenv().LowGpu = true

  SafeNotify("Tối ưu (Auto)", "Phát hiện: "..tostring(reason)..".\nBật Low Mode để giảm tải.")
  if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Tự động kích hoạt Low Mode do: " .. tostring(reason), "WARN") end

  task.spawn(function()
    pcall(function()
      -- [PERF] KHÔNG tự đổi QualityLevel / GlobalShadows / FogEnd nữa (chỉ khi người dùng bấm "Fix lag" / "Giảm đồ họa")

      pcall(function()
        if LoadingGui and LoadingGui.Parent then
          local ub = LoadingGui:FindFirstChild("UniverseBackground", true)
          if ub and ub:IsA("ImageLabel") then ub.ImageTransparency = 1 end
        end
      end)

      if CurrentMusic then
        pcall(function()
          if CurrentMusic.Stop then CurrentMusic:Stop() end
          if CurrentMusic.Destroy then CurrentMusic:Destroy() end
          CurrentMusic = nil
          _G.HzMusicRuntime = nil
        end)
      end
    end)
  end)
end

local function safeLoadSmart(name, url, preFn)
  if type(preFn) == "function" then
    pcall(preFn)
  end

  local executableScript = 'loadstring(game:HttpGet("' .. url .. '"))()'

  if _G.f8eefa956e6130f83 then
    if _G.e37669d62d5f58e0d >= 3 then
      SafeNotify(name, "❌ Đã hết lượt copy (Tối đa 3 lần)!")
      return false
    end

    local ok = pcall(function()
      if setclipboard then setclipboard(executableScript) end
    end)

    if ok then
      _G.e37669d62d5f58e0d = _G.e37669d62d5f58e0d + 1
      SafeNotify(name, "✅ Đã copy script vào clipboard!\n(" .. _G.e37669d62d5f58e0d .. "/3)")
      if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Copy script thông minh: " .. name, "SUCCESS") end
    else
      SafeNotify(name, "❌ Executor không hỗ trợ copy!")
    end
    return true
  end

  local slowDetected, avgFps, ping = detectSlowNetOrWeakDevice()

  if slowDetected then
    local reason = ("FPS=%d, PING=%s"):format(math.floor(avgFps or 0), ping and tostring(math.floor(ping)) or "N/A")
    enableLowMode(reason)
  end

  if type(safeLoad) == "function" then
    return safeLoad(name, url)
  else
    SafeNotify(name, "Đang load script...")
    local ok2, result = pcall(function()
      local code = game:HttpGet(url, true)
      if code == "404: Not Found" or code == "Not Found" or string.find(code, "404 Not Found") then
        return "DEAD_SCRIPT"
      end
      local fn = loadstring(code)
      if fn then
        fn()
        return "SUCCESS"
      else
        return "SYNTAX_ERROR"
      end
    end)

    if not ok2 then
      if tostring(result):find("404") or tostring(result):find("Not Found") then
        SafeNotify(name, "❌ Script này đã bị xóa bởi tác giả!")
         if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Script (Smart) tải lỗi 404: " .. name, "ERROR") end
      else
        SafeNotify(name, "Load thất bại: "..tostring(result))
        if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Script (Smart) Load thất bại: " .. name .. " - " .. tostring(result), "ERROR") end
      end
      return nil
    elseif result == "DEAD_SCRIPT" then
      SafeNotify(name, "❌ Script này đã bị xóa bởi tác giả!")
      if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Script (Smart) Chặn Script Chết: " .. name, "WARN") end
      return nil
    end
    SafeNotify(name, "Hoàn thành load script!")
    if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Script (Smart) Hoàn thành: " .. name, "SUCCESS") end
    return true
  end
end

task.spawn(function()
  task.wait(2)
  local slowDetected, avgFps, ping = detectSlowNetOrWeakDevice()
  if slowDetected or (avgFps and avgFps < 15) or (ping and ping > 400) then
    enableLowMode("Auto-check (FPS="..math.floor(avgFps or 0)..", PING="..(ping and tostring(math.floor(ping)) or "N/A")..")")
  end
end)

-- ===== [SCRIPT DB] DANH SÁCH SCRIPT LẤY TỪ GITHUB RIÊNG =====
-- Upload file scripts.json lên repo GitHub của bạn rồi sửa URL bên dưới (có thể thêm link dự phòng).
_G.a3e3d0c9f814ab79a = _G.a3e3d0c9f814ab79a or {
  "https://raw.githubusercontent.com/hidescript/x8k2-db/refs/heads/main/script.json",
}

_G.cac14455b47959295 = function()
  local HttpService = game:GetService("HttpService")
  local CACHE_DIR, CACHE_FILE = "x8k2", "x8k2/scripts_cache.json"
  local function log(msg, lvl) if _G.aa3542001e064bc52 then _G.aa3542001e064bc52(msg, lvl) end end
  local function valid(db) return type(db) == "table" and type(db.lists) == "table" end

  for _, url in ipairs(_G.a3e3d0c9f814ab79a) do
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and type(body) == "string" and body ~= "" then
      local okJ, db = pcall(function() return HttpService:JSONDecode(body) end)
      if okJ and valid(db) then
        pcall(function()
          if writefile then
            if makefolder and isfolder and not isfolder(CACHE_DIR) then makefolder(CACHE_DIR) end
            writefile(CACHE_FILE, body)
          end
        end)
        return db, "GitHub"
      end
      log("scripts.json sai định dạng JSON: " .. tostring(url), "ERROR")
    else
      log("Không tải được scripts.json: " .. tostring(url), "WARN")
    end
  end

  -- Dự phòng: dùng bản cache lần tải thành công gần nhất
  local okC, cached = pcall(function()
    if isfile and readfile and isfile(CACHE_FILE) then
      return HttpService:JSONDecode(readfile(CACHE_FILE))
    end
  end)
  if okC and valid(cached) then return cached, "cache" end
  return nil
end

do
  local ok, db, src = pcall(_G.cac14455b47959295)
  _G.ed9403ec91bccc54c = (ok and type(db) == "table") and db or nil
  if _G.ed9403ec91bccc54c then
    local n = 0
    for _ in pairs(_G.ed9403ec91bccc54c.lists) do n = n + 1 end
    if _G.aa3542001e064bc52 then
      _G.aa3542001e064bc52(string.format(_G.tR9("Đã tải DB script v%s (%d danh sách) từ %s"), tostring(db.version or "?"), n, tostring(src)), src == "cache" and "WARN" or "SUCCESS")
    end
  elseif _G.aa3542001e064bc52 then
    _G.aa3542001e064bc52("Không tải được DB script (GitHub + cache đều lỗi).", "ERROR")
  end
end

-- [V35] C1: DB có places/universes → lưu cache + nhận diện lại (HzG là bảng cờ; tab game dựng phía dưới)
pcall(function()
  if _G.HzPlacesApply(_G.ed9403ec91bccc54c) and not HzG.any then
    local f = _G.HzDetectGame(PlaceID, UniverseID, GameName)
    for k, v in pairs(f) do HzG[k] = v end
  end
end)

_G.feb30fee1c45c6a5e = function(tab, key)
  local db = _G.ed9403ec91bccc54c
  local list = db and db.lists and db.lists[key]
  if type(list) ~= "table" then
    if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Thiếu danh sách script: " .. tostring(key), "WARN") end
    pcall(function() tab:CreateLabel("⚠️ Không tải được danh sách script [" .. tostring(key) .. "]. Kiểm tra mạng/URL GitHub rồi execute lại.") end)
    return
  end
  local curLang = (_G.lG10 and _G.lG10()) or "vi"
  local gen2 = _G.gL22 == true
  local function strip(x) return (tostring(x):gsub("^📌%s*", "")) end

  -- Nguồn là tiếng Việt; không có *_en thì giữ nguyên.
  if gen2 and _G.rT17 then -- [FIX LANG] tự dịch qua _G.tT19 khi DB thiếu *_en / *_pt
    local map, mapP = {}, {}
    local function enOf(s)
      if not s or not _G.tT19 then return nil end
      return _G.tT19(tostring(s), "en")
    end
    local function ptOf(s)
      if not s or not _G.tT19 then return nil end
      return _G.tT19(tostring(s), "pt")
    end
    local function put(k, v, vp)
      if not k or k == "" then return end
      if v and v ~= k then map[k] = v end
      if vp and vp ~= k then mapP[k] = vp end
    end
    for _, item in ipairs(list) do
      if type(item) == "table" then
        if item.section then
          local k = strip(item.section)
          put(k,
            item.section_en and strip(item.section_en) or enOf(k),
            item.section_pt and strip(item.section_pt) or ptOf(k))
        end
        if item.name then
          local k = tostring(item.name)
          put(k,
            item.name_en or enOf(k),
            item.name_pt or ptOf(k))
        end
        if item.title then
          local k = tostring(item.title)
          put(k,
            item.title_en or enOf(k),
            item.title_pt or ptOf(k))
        end
        if item.note then
          local k = tostring(item.note)
          put(k,
            item.note_en or enOf(k),
            item.note_pt or ptOf(k))
        end
      end
    end
    _G.rT17(map, mapP)
  end
  local function txt(vi, enTxt, ptTxt)
    if gen2 then return vi end
    if curLang == "en" then return enTxt or vi end
    if curLang == "pt" then return ptTxt or enTxt or vi end
    return vi
  end

  local function shortName(raw)
    local s = tostring(raw)
    local len = utf8.len(s) or #s
    if len <= 28 then return s, nil end
    local first
    for _, sep in ipairs({ " & ", " : ", ":", ",", " (" }) do
      local p = s:find(sep, 1, true)
      if p and p > 8 and (not first or p < first) then first = p end
    end
    if first then
      local head = (s:sub(1, first - 1):gsub("%s+$", ""))
      if (utf8.len(head) or #head) <= 28 then return head, s end
    end
    local off = utf8.offset(s, 29)
    if not off then return s, nil end
    return s:sub(1, off - 1) .. "...", s
  end

  local built = 0 -- [V26] đếm nút đã dựng để nhường khung hình, tránh đứng hình khi dựng 140+ nút một lượt
  local batchSize = _G.HzPerfPick(8, 5, 2) -- [PERF] HIGH 8 | MED 5 | LOW 2
  for _, item in ipairs(list) do
    if type(item) == "table" then
      if item.section then
        tab:CreateSection(strip(txt(item.section, item.section_en, item.section_pt)))
      elseif item.name and type(item.url) == "string" and item.url:sub(1, 8) == "https://" and item.disabled ~= true then
        local btnName, fullName = shortName(txt(item.name, item.name_en, item.name_pt))
        local title = tostring(item.title or (fullName and btnName) or item.name)
        local noteText = txt(item.note, item.note_en, item.note_pt)
        local descText = noteText and tostring(noteText) or nil
        if fullName then descText = descText and (fullName .. "\n" .. descText) or fullName end
        local url = item.url
        local smart = item.smart == true
        tab:CreateButton({
          Name = btnName,
          Description = descText,
          Callback = function()
            if type(item.genv) == "table" then
              for k, v in pairs(item.genv) do
                if type(k) == "string" and (type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
                  getgenv()[k] = v
                end
              end
            end
            if smart then safeLoadSmart(title, url) else safeLoad(title, url) end
            if _G.HzAutoRestore then pcall(_G.HzAutoRestore.track, title, url, "db", { genv = item.genv }) end
          end,
        })
        built = built + 1
        if built % batchSize == 0 then task.wait(_G.HzPerfLvl == "low" and 0.05 or 0.03) end -- [PERF]
      end
    end
  end
end

local TabAbout = Window:CreateTab("Về Hub", tonumber("4871684504"))

_G.sT1 = _G.sT1 or tick()
if type(_G.sT1) == "string" then
  _G.sT1 = tonumber(_G.sT1) or tick()
end
if type(_G.sT1) ~= "number" then
  _G.sT1 = tick()
end

do
  local LS = HzUiS
  local Players = game:GetService("Players")
  local TweenService = game:GetService("TweenService")
  local Stats = game:GetService("Stats")
  local LP = Players.LocalPlayer

  ----------------------------------------------------------------
  -- Tiện ích
  ----------------------------------------------------------------
  local cache = setmetatable({}, { __mode = "k" })
  local function setLbl(h, text)
    if type(h) ~= "table" or cache[h] == text then return end
    cache[h] = text
    pcall(function()
      if h.Set then h:Set(text) elseif h.SetText then h:SetText(text) end
    end)
  end

  local function hms(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
  end

  local function getMem()
    local ok, v = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
    return (ok and tonumber(v)) and math.floor(v) or 0
  end

  local function executorName()
    local name
    pcall(function()
      local g = getgenv()
      name = g.ExecutorName
      if (name == nil or name == "") and g.HzAllowIdentify == true and type(identifyexecutor) == "function" then
        name = (identifyexecutor()) -- chỉ khi người dùng chủ động cho phép
      end
    end)
    if type(name) ~= "string" then return "Unknown" end
    local clean = name:gsub("%c", "")  -- bỏ ký tự điều khiển
    clean = clean:sub(1, 32)           -- giới hạn độ dài hiển thị
    if clean:gsub("%s", "") == "" then return "Unknown" end
    return clean
  end

  local function greeting()
    local h = tonumber(os.date("%H")) or 12
    if h >= 5 and h < 11 then return LS("Chào buổi sáng")
    elseif h >= 11 and h < 18 then return LS("Chào buổi chiều")
    elseif h >= 18 and h < 23 then return LS("Chào buổi tối")
    else return LS("Khuya rồi, nghỉ sớm nhé") end
  end

  -- Pháo hoa giấy rơi khắp màn hình
  local function Confetti(count)
    -- [PERF] HIGH: giữ nguyên | MED: ×0.5 | LOW: bỏ hẳn (click SFX vẫn chạy ở callback bọc ngoài)
    local lv = _G.HzPerfLvl or "high"
    if lv == "low" then return end
    if lv == "med" then count = math.max(1, math.floor((tonumber(count) or 0) * 0.5)) end
    pcall(function()
      local gui = Instance.new("ScreenGui")
      gui.Name = HzN.confetti
      gui.IgnoreGuiInset = true
      gui.ResetOnSpawn = false
      gui.DisplayOrder = 999
      pcall(function() gui.Parent = game:GetService("CoreGui") end)
      if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
      local chars = { "✨", "🎉", "🎊", "⭐", "💜", "💙", "🌟" }
      for _ = 1, count do
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Text = chars[math.random(#chars)]
        l.TextSize = math.random(18, 34)
        l.Size = UDim2.new(0, 40, 0, 40)
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        local x = math.random()
        l.Position = UDim2.new(x, 0, 0, -40)
        l.Rotation = math.random(-40, 40)
        l.Parent = gui
        task.delay(math.random() * 0.9, function()
          pcall(function()
            TweenService:Create(l, TweenInfo.new(1.8 + math.random() * 1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
              Position = UDim2.new(x, math.random(-70, 70), 1, 60),
              Rotation = l.Rotation + math.random(-220, 220),
              TextTransparency = 0.8,
            }):Play()
          end)
        end)
      end
      task.delay(5, function() pcall(function() gui:Destroy() end) end)
    end)
  end

  local name = _G.HzDisplayName()

  TabAbout:CreateDivider({ text = "Chào mừng" })
  TabAbout:CreateSection("Chào mừng")
  local HelloLabel = TabAbout:CreateLabel("👋 " .. greeting() .. ", " .. name .. "!")
  local TaglineLabel = TabAbout:CreateLabel("✨ H")
  TabAbout:CreateParagraph({
    Title = "Có gì trong H?",
    Content = "• Script riêng cho từng game\n• Trình phát nhạc + HUD kéo thả\n• Kho script: lưu và đồng bộ máy khác\n• Tối ưu FPS, dọn chat, đổi server nhanh",
  })

  TabAbout:CreateDivider({ text = "Trực tiếp" })
  TabAbout:CreateSection("Trực tiếp")
  local SrvLabel = TabAbout:CreateLabel("👥 …")
  local SrvTimeLabel = TabAbout:CreateLabel("⏱️ …")
  local RamProg = TabAbout:CreateProgress({ name = "🧠 RAM", range = { 0, 4000 }, value = 0,
    format = function(v, _, mx) return string.format("%d / ~%d MB", math.floor((v or 0) + 0.5), math.floor((mx or 0) + 0.5)) end })
  local ClockLabel = TabAbout:CreateLabel("🕒 …")
  local UptimeLabel = TabAbout:CreateLabel("⏳ …")

  TabAbout:CreateDivider({ text = "Game" })
  TabAbout:CreateSection("Game")
  local function gameText() return "🎮 " .. LS("Game: ") .. tostring(GameName or "N/A") end
  local function verText() return "📦 " .. LS("Phiên bản: ") .. "V41 AutoLoad · " .. tostring(_G.sV7 or "BETA") end
  local GameLabel = TabAbout:CreateLabel(gameText())
  TabAbout:CreateLabel("PlaceID: " .. tostring(PlaceID or "N/A"))
  TabAbout:CreateLabel("Job: " .. (tostring(game.JobId or ""):sub(1, 8) ~= "" and tostring(game.JobId):sub(1, 8) or "Studio"))
  TabAbout:CreateLabel("Executor: " .. executorName())
  -- [V36] tagline thương hiệu
  TabAbout:CreateLabel(_G.tR9("HiulzHub — gọn · mượt · không drama"))
  local VerLabel = TabAbout:CreateLabel(verText())

  TabAbout:CreateDivider({ text = "Cộng đồng" })
  TabAbout:CreateSection("Cộng đồng")
  TabAbout:CreateButton({
    Name = " Discord",
    Icon = tonumber("135213496660537"),
    Callback = function()
      local ok = pcall(function() setclipboard("https://discord.gg/UcFrgBPZbZ") end)
      Notify("Discord", ok and "Đã copy link Discord!" or "Executor không hỗ trợ copy.")
    end,
  })
  TabAbout:CreateButton({
    Name = " TikTok",
    Icon = tonumber("81671159882894"),
    Callback = function()
      local ok = pcall(function() setclipboard("https://www.tiktok.com/@67_hubdiscord") end)
      Notify("TikTok", ok and "Đã copy link TikTok!" or "Executor không hỗ trợ copy.")
    end,
  })
  TabAbout:CreateButton({
    Name = " Pháo hoa",
    Icon = tonumber("121415938028915"),
    Callback = function() Confetti(45) end, -- [PERF] Confetti() tự giảm ×0.5 (MED) / bỏ (LOW)
  })


  local CHANGELOG = {
    { ver = "V41-PC", date = "07/11/2026", items = {
      { "NEW", "Tự nạp lại hub khi đổi server, vào lại hoặc bị kick: công tắc Tự nạp lại hub khi đổi server ở Tuỳ chỉnh → Giữ phiên script (mặc định bật, cần executor hỗ trợ queue_on_teleport)", "Hub reloads itself when you switch servers, rejoin or get kicked: new switch Auto reload hub on server switch in Customize → Script session keeper (on by default, needs an executor with queue_on_teleport)", "O hub recarrega sozinho ao trocar de servidor, voltar ao jogo ou ser expulso: novo botão Recarregar o hub automaticamente ao trocar de servidor em Personalizar → Manter sessão de scripts (ativado por padrão, requer executor com queue_on_teleport)" },
      { "UPD", "Ô Link hoặc file hub: để trống sẽ dùng link mặc định của HiulzHub", "Hub link or file box: leave empty to use the default HiulzHub link", "Campo Link ou arquivo do hub: deixe vazio para usar o link padrão do HiulzHub" },
      { "UPD", "Nút Đổi server / Vào lại / JobID và Auto Rejoin hẹn nạp lại hub trước khi dịch chuyển; bộ nghe kick cũng chạy khi chỉ bật nạp lại hub", "Server hop / Rejoin / JobID buttons and Auto Rejoin queue the hub reload before teleporting; the kick listener also runs when only hub reload is on", "Botões Trocar servidor / Reentrar / JobID e o Auto Rejoin agendam o recarregamento do hub antes de teletransportar; o ouvinte de kick também roda quando só o recarregamento do hub está ativo" },
    } },
    { ver = "V36-PC", date = "05/11/2026", items = {
      { "UPD", "Giao diện gọn hơn: bỏ emoji ở tên nút, mục và nhãn (giữ toast và huy hiệu trạng thái)", "Cleaner UI: removed emoji from buttons, sections and labels (toasts and status badges kept)", "Interface mais limpa: emojis removidos de botões, seções e rótulos (toasts e selos de status mantidos)" },
      { "NEW", "Dòng thương hiệu ở tab Về Hub", "Brand tagline in the About tab", "Slogan da marca na aba Sobre" },
      { "UPD", "Đổi tên tab: Thông tin → Về Hub, Cài đặt → Tuỳ chỉnh", "Tabs renamed: Info → About, Settings → Customize", "Abas renomeadas: Informações → Sobre, Configurações → Personalizar" },
      { "UPD", "Xoá code thừa: hàm/biến không dùng, khai báo service trùng, pcall dư", "Removed dead code: unused functions/variables, duplicate service locals, redundant pcalls", "Removido código morto: funções/variáveis sem uso, serviços duplicados, pcalls redundantes" },
      { "FIX", "Bảng dịch khớp nguyên chuỗi cho các nhãn ngắn mới (không làm hỏng chuỗi khác)", "Exact-match translations for the new short labels (other strings stay intact)", "Traduções de correspondência exata para os novos rótulos curtos (outras strings intactas)" },
    } },
    { ver = "V35-PC", date = "05/11/2026", items = {
      { "NEW", "Toast tuỳ chỉnh _G.HzToast (5 mức, xếp chồng, tối đa 3 cùng lúc)", "Custom toast _G.HzToast (5 levels, stacked, max 3 at once)", "Toast personalizado _G.HzToast (5 níveis, empilhado, máx. 3 ao mesmo tempo)" },
      { "NEW", "Tab nặng chỉ dựng khi mở lần đầu (_G.HzLazyTab)", "Heavy tabs are built on first open (_G.HzLazyTab)", "Abas pesadas só são criadas na primeira abertura (_G.HzLazyTab)" },
      { "NEW", "Âm thanh click cho nút/công tắc/toast", "Click sound for buttons/toggles/toasts", "Som de clique em botões/alternadores/toasts" },
      { "NEW", "Màn loading có 6 chấm tiến trình", "Loading screen shows 6 progress dots", "Tela de carregamento com 6 pontos de progresso" },
      { "NEW", "Hằng số tập trung _G.HzConst", "Centralized constants _G.HzConst", "Constantes centralizadas _G.HzConst" },
      { "UPD", "Danh sách PlaceId/UniverseId đọc từ scripts.json + cache 7 ngày", "PlaceId/UniverseId lists read from scripts.json + 7-day cache", "Listas de PlaceId/UniverseId lidas do scripts.json + cache de 7 dias" },
      { "UPD", "Theme hiển thị kèm emoji", "Theme names shown with emoji", "Nomes de tema exibidos com emoji" },
      { "UPD", "HUD FPS/Ping chỉ ghi nhãn mỗi 0,5 giây", "FPS/Ping HUD updates labels every 0.5s", "HUD FPS/Ping atualiza os rótulos a cada 0,5 s" },
      { "UPD", "Rút gọn quét tên Mask (gốc + 1 lần 1,5s)", "Simplified Mask name scan (initial + one pass at 1.5s)", "Varredura do nome Mask simplificada (inicial + 1 vez em 1,5 s)" },
      { "UPD", "Kết nối được theo dõi bằng bảng băm (không trùng)", "Connections tracked in a hash table (no duplicates)", "Conexões rastreadas em tabela hash (sem duplicatas)" },
      { "UPD", "Vòng nhạc nghỉ nhịp khi không phát; log/HUD tạm dừng khi menu ẩn", "Music loop slows down when idle; log/HUD pause while menu is hidden", "Loop de música desacelera quando ocioso; log/HUD pausam com o menu oculto" },
      { "FIX", "Bỏ chờ thừa ở nhận diện game", "Removed redundant wait in game detection", "Removida espera redundante na detecção de jogo" },
      { "FIX", "Cleanup dọn được cả danh sách kết nối kiểu cũ (V34)", "Cleanup also handles old-style (V34) connection lists", "A limpeza também trata listas de conexões do estilo antigo (V34)" },
    } },
    { ver = "V34-PC", date = "04/11/2026", items = {
      { "FIX", "Tab Thông tin: bỏ dòng RAM lỗi (biến chưa khai báo)", "About tab: removed the broken RAM line (undeclared variable)", "Aba Informações: removida a linha de RAM com erro (variável não declarada)" },
      { "FIX", "Ô Góp ý tự xoá chữ sau khi gửi như trước", "The Feedback box clears its text after sending again", "A caixa de Feedback volta a limpar o texto após enviar" },
      { "UPD", "Tab Tối ưu: dọn khai báo trùng", "Optimize tab: removed duplicate declarations", "Aba Otimizar: removidas declarações duplicadas" },
      { "UPD", "Khởi động nhanh hơn: tên game chờ tối đa 1.2 giây, tải xong sẽ tự cập nhật", "Faster startup: game name waits at most 1.2s, then updates itself", "Inicialização mais rápida: o nome do jogo espera no máximo 1,2s e atualiza sozinho" },
      { "UPD", "ScriptBlox lưu cache ra file 5 phút: mở lại menu không phải chờ", "ScriptBlox cache saved to file for 5 minutes: reopening the menu does not wait", "Cache do ScriptBlox salvo em arquivo por 5 minutos: reabrir o menu não espera" },
      { "NEW", "Nút ▶ Chạy Auto-run ngay ở Cài đặt", "▶ Run Auto-run now button in Settings", "Botão ▶ Executar Auto-run agora em Configurações" },
      { "NEW", "Hỏi xác nhận trước khi Bỏ ghim tất cả, Xoá script, Quét sạch log", "Confirmation before Unpin all, Delete script, Clear log", "Confirmação antes de Desafixar tudo, Excluir script, Limpar log" },
      { "NEW", "Tự báo khi có bản mới", "Automatic notice when a new version is out", "Aviso automático quando há versão nova" },
      { "UPD", "Auto-run cảnh báo trong log khi link không thuộc host tin cậy", "Auto-run logs a warning for links outside trusted hosts", "Auto-run registra um aviso para links fora dos hosts confiáveis" },
      { "UPD", "Key góp ý đổi được qua _G.HzFeedbackKey", "Feedback key can be changed via _G.HzFeedbackKey", "A chave de feedback pode ser alterada via _G.HzFeedbackKey" },
    } },
    { ver = "V33-PC", date = "01/11/2026", items = {
      { "NEW", "Ẩn tên người chơi (Mask): chỉ hiện 3 ký tự đầu, còn lại thay bằng *; bật/tắt ở Cài đặt → Hệ thống", "Player name mask: only the first 3 characters are shown, the rest become *; toggle in Settings → System", "Máscara do nome do jogador: só os 3 primeiros caracteres aparecem, o resto vira *; ative em Configurações → Sistema" },
      { "NEW", "Chọn giao diện menu bằng 6 theme Rayfield Gen2 (Default, Cobalt, Ember, Amethyst, Frost, Rose); nhớ lại sau khi mở lại menu", "Pick the menu look from 6 Rayfield Gen2 themes (Default, Cobalt, Ember, Amethyst, Frost, Rose); remembered next time", "Escolha o visual do menu entre 6 temas do Rayfield Gen2 (Default, Cobalt, Ember, Amethyst, Frost, Rose); lembrado na próxima vez" },
      { "NEW", "🛡️ Anti-AFK (ngẫu nhiên 60–180 giây) và 🔄 Tự động vào lại khi bị đá ở Cài đặt → Hệ thống", "🛡️ Anti-AFK (random 60–180 seconds) and 🔄 Auto rejoin when kicked in Settings → System", "🛡️ Anti-AFK (aleatório de 60–180 segundos) e 🔄 Reentrada automática ao ser expulso em Configurações → Sistema" },
      { "UPD", "☄️ Tự động chạy: nút ở Kho script đổi thành Đã bật (Bấm để tắt); Cài đặt có danh sách script đang Auto-run + nút tắt từng script; bỏ nút Ghim ở ScriptBlox", "☄️ Auto-run: the Vault button turns into Enabled (tap to turn off); Settings lists Auto-run scripts with a per-script off button; the Pin button was removed from ScriptBlox", "☄️ Auto-run: o botão do Cofre vira Ativado (toque para desligar); Configurações lista os scripts em Auto-run com botão para desligar cada um; o botão Fixar saiu do ScriptBlox" },
    } },
    { ver = "V32-PC", date = "01/11/2026", items = {
      { "NEW", "Ghim script (⭐ Ghim) ở tab Kho script và ScriptBlox: script đã ghim tự chạy khi khởi động (lưu tên + link ở x8k2/autoload.json); bật/tắt và bỏ ghim ở Cài đặt", "Pin scripts (⭐ Pin) in the Vault and ScriptBlox tabs: pinned scripts auto-run on startup (name + link saved in x8k2/autoload.json); toggle and unpin in Settings", "Fixe scripts (⭐ Fixar) nas abas Cofre e ScriptBlox: scripts fixados rodam sozinhos ao iniciar (nome + link salvos em x8k2/autoload.json); ative/desative e desafixe em Configurações" },
      { "NEW", "Tab ScriptBlox có nút 💾 Lưu vào Kho: thêm script đang xem vào Kho script chỉ với một lần bấm", "The ScriptBlox tab has a 💾 Save to vault button: add the script you are viewing to the script vault in one tap", "A aba ScriptBlox tem o botão 💾 Salvar no cofre: adicione o script que você está vendo ao cofre de scripts com um toque" },
      { "NEW", "Phím tắt đổi được ở Cài đặt: ẩn/hiện menu (RightShift) và bật/tắt nhạc (M)", "Rebindable shortcuts in Settings: show/hide the menu (RightShift) and play/pause music (M)", "Atalhos configuráveis em Configurações: mostrar/ocultar o menu (RightShift) e pausar/retomar a música (M)" },
      { "NEW", "Lỗi của script bên ngoài được ghi kèm tên script vào x8k2/error_log.txt để dễ báo cáo", "Errors from external scripts are saved with the script name to x8k2/error_log.txt for easy reporting", "Erros de scripts externos são salvos com o nome do script em x8k2/error_log.txt para facilitar o relato" },
      { "UPD", "Tách nhận diện game (_G.HzDetectGame) và dọn dẹp re-execute (_G.HzCleanUp) ra khỏi StartRayfield: ít biến local hơn, an toàn hơn với giới hạn 200", "Game detection (_G.HzDetectGame) and re-execute cleanup (_G.HzCleanUp) moved out of StartRayfield: fewer locals, safer against the 200 limit", "Detecção de jogo (_G.HzDetectGame) e limpeza de re-execução (_G.HzCleanUp) saíram do StartRayfield: menos locais, mais seguro contra o limite de 200" },
      { "UPD", "Ẩn tên Roblox trong menu (hiện \"Player\"); dòng trạng thái đổi thành V32 KING LEGACY", "Roblox username hidden in the menu (shows \"Player\"); status line is now V32 KING LEGACY", "Nome de usuário do Roblox oculto no menu (mostra \"Player\"); a linha de status agora é V32 KING LEGACY" },
    } },
    { ver = "V31-PC", date = "31/10/2026", items = {
      { "NEW", "Hỗ trợ game King Legacy (tab mới, nhận diện cả Sea 1/2/3)", "Added King Legacy support (new tab, detects Sea 1/2/3)", "Adicionado suporte ao King Legacy (nova aba, detecta Sea 1/2/3)" },
      { "NEW", "Thêm tab ScriptBlox (ngay dưới tab Khác): xem script mới nhất từ scriptblox.com, tìm kiếm, lọc Verified/không key/Universal, phân trang, copy loadstring hoặc chạy", "Added a ScriptBlox tab (right below Other): browse the latest scripts from scriptblox.com, search, filter Verified/keyless/Universal, paginate, copy the loadstring or run", "Adicionada a aba ScriptBlox (logo abaixo de Outros): veja os scripts mais recentes do scriptblox.com, pesquise, filtre por Verified/sem key/Universal, pagine, copie o loadstring ou execute" },
      { "NEW", "Tab ScriptBlox ghi rõ nguồn; script chỉ chạy khi bạn bấm ▶ Chạy, script cần key hoặc có thể đã Patched sẽ hỏi xác nhận trước", "The ScriptBlox tab credits its source; scripts only run when you press ▶ Run, and key/patched scripts ask for confirmation first", "A aba ScriptBlox indica a fonte; os scripts só rodam quando você toca em ▶ Executar, e scripts com key ou patcheados pedem confirmação antes" },
    } },
    { ver = "V30-PC", date = "31/10/2026", items = {
      { "FIX", "Sửa lỗi lệch ngôn ngữ tab Thông tin: Game/Phiên bản và các dòng trực tiếp luôn cùng ngôn ngữ với tab", "Fixed mixed languages in the Info tab: Game/Version and live lines now match the tabs", "Corrigido o idioma misturado na aba Info: Jogo/Versão e linhas ao vivo seguem o idioma das abas" },
      { "NEW", "Thêm đường kẻ chia nhóm (Divider) ở các tab Thông tin, Nhạc, Cài đặt, Kho script, Server", "Added group dividers in the Info, Music, Settings, Vault and Server tabs", "Adicionados divisores de grupo nas abas Info, Música, Configurações, Cofre e Servidor" },
      { "NEW", "Thêm thanh tiến trình (Progress): kiểm tra/nhập script, thu thập server, RAM", "Added progress bars: script check/import, server fetch, RAM", "Adicionadas barras de progresso: verificação/importação de scripts, coleta de servidores, RAM" },
    } },
    { ver = "V29-PC", date = "31/10/2026", items = {
      { "NEW", "Thông báo ngắn hiện dạng toast gọn; có toast khi menu tải xong", "Short messages now appear as compact toasts; toast when the menu is ready", "Mensagens curtas agora aparecem como toasts compactos; toast quando o menu estiver pronto" },
      { "NEW", "Dòng trạng thái dưới tên bạn ở thanh bên: hiện bài nhạc đang phát", "Sidebar profile line shows the song that is playing", "A linha de perfil na barra lateral mostra a música que está tocando" },
      { "UPD", "Nhẹ hơn: bỏ bộ đếm FPS thừa ở tab Thông tin, vòng lặp nhạc dừng khi đóng menu", "Lighter: removed the unused FPS counter in the Info tab; the music loop stops when the menu closes", "Mais leve: removido o contador de FPS não usado na aba Info; o loop da música para ao fechar o menu" },
    } },
    { ver = "V28-PC", date = "29/10/2026", items = {
      { "NEW", "Thêm ngôn ngữ Português (Brasil): tự nhận khi ở Brazil, hoặc chọn ở Cài đặt", "Added Português (Brasil): auto-detected in Brazil, or pick it in Settings", "Adicionado o idioma Português (Brasil): detecção automática no Brasil, ou escolha em Configurações" },
      { "FIX", "Dòng Executor ở tab Thông tin hiện tên executor thật thay vì dấu ?", "The Executor line in the Info tab now shows the real executor name instead of ?", "A linha Executor na aba Info agora mostra o nome real do executor em vez de ?" },
    } },
    { ver = "V27-PC", date = "29/10/2026", items = {
      { "UPD", "Khởi động nhẹ hơn nữa trên máy yếu: bỏ quét Workspace, cache admin + thư viện UI", "Even lighter startup on weak devices: no Workspace scan, cached admin list + UI library", "Inicialização ainda mais leve em dispositivos fracos: sem varredura do Workspace, lista de admins e biblioteca de UI em cache" },
      { "UPD", "Loading LITE đi thẳng 100%, nút nhạc/danh sách dựng lười để đỡ giật", "LITE loading jumps straight to 100%; music list and script buttons are built lazily", "O loading LITE vai direto a 100%; lista de músicas e botões de script são montados sob demanda" },
      { "NEW", "Đo thời gian khởi động: _G.HzPerfDebug = true (xem trong tab Nhật Ký)", "Startup timing: _G.HzPerfDebug = true (see the Log tab)", "Medição do tempo de inicialização: _G.HzPerfDebug = true (veja na aba Log)" },
    } },
    { ver = "V26-PC", date = "29/10/2026", items = {
      { "UPD", "Mở script nhẹ hơn trên máy yếu: tự giảm hiệu ứng loading (LITE)", "Lighter startup on weak devices: loading effects scale down automatically (LITE)", "Inicialização mais leve em dispositivos fracos: os efeitos do loading diminuem automaticamente (LITE)" },
      { "UPD", "Dựng danh sách script theo từng đợt, không còn đứng hình khi mở menu", "Script list is built in small batches, no more freeze when the menu opens", "A lista de scripts é montada em pequenos lotes, sem travar ao abrir o menu" },
      { "FIX", "Bỏ quét Workspace lặp 2 lần lúc khởi động", "Removed the duplicated Workspace scan at startup", "Removida a varredura duplicada do Workspace na inicialização" },
      { "UPD", "HUD nhạc và pháo hoa chào mừng nhẹ hơn", "Music HUD and welcome confetti are lighter", "HUD de música e confete de boas-vindas mais leves" },
      { "NEW", "Ép tay chế độ nhẹ: getgenv().HzLiteLoading = true", "Force light mode manually: getgenv().HzLiteLoading = true", "Forçar o modo leve manualmente: getgenv().HzLiteLoading = true" },
    } },
    { ver = "V25-PC", date = "28/10/2026", items = {
      { "NEW", "Bấm RightShift để ẩn/hiện menu trên máy tính", "RightShift hides/shows the menu on PC", "RightShift mostra/oculta o menu no PC" },
      { "UPD", "Màn hình loading co giãn theo cỡ màn hình", "Loading screen now fits big screens", "A tela de loading agora se ajusta a telas grandes" },
      { "UPD", "Tab Steal an Egg có icon mới", "New icon for the Steal an Egg tab", "Novo ícone para a aba Steal an Egg" },
      { "DB",  "Kho script có thêm vài script mới", "A few new scripts in the vault", "Alguns scripts novos no cofre" },
      { "NEW", "Tab Thông tin có nhật ký cập nhật (chính là bảng này)", "The Info tab now has an update log (this one)", "A aba Info agora tem um log de atualizações (este aqui)" },
    } },
    { ver = "V24", items = {
      { "NEW", "Góp ý gửi đi theo đúng ngôn ngữ bạn đang dùng", "Feedback now follows the language you picked", "O feedback agora segue o idioma que você escolheu" },
    } },
    { ver = "V23", items = {
      { "UPD", "Góp ý gọn và dễ đọc hơn, có phân loại và mức ưu tiên", "Cleaner feedback with type and priority", "Feedback mais limpo, com tipo e prioridade" },
      { "UPD", "Góp ý kèm thông tin máy cơ bản để dễ hỗ trợ hơn", "Feedback includes basic device info so we can help faster", "O feedback inclui informações básicas do dispositivo para ajudarmos mais rápido" },
    } },
    { ver = "V22", items = {
      { "FIX", "Menu mượt hơn, đóng menu là các vòng lặp nền dừng hẳn", "Smoother menu, background loops stop when you close it", "Menu mais fluido; ao fechar, os loops em segundo plano param" },
      { "FIX", "Thông báo ổn định hơn, ít bị lỗi vặt", "Notifications are steadier, fewer small glitches", "Notificações mais estáveis, com menos falhas pequenas" },
    } },
    { ver = "V19", items = {
      { "NEW", "Đổi ngôn ngữ ngay trong menu, hỏi lại trước khi đóng toàn bộ", "Switch language in the menu, with a confirm before closing everything", "Troque o idioma no menu, com confirmação antes de fechar tudo" },
    } },
  }
  do
    if type(_G.rT17) == "function" then
      pcall(_G.rT17, {
        ["📝 Nhật ký cập nhật"] = "📝 Update log",
        ["Nhật ký cập nhật"] = "Update log",
      }, {
        ["📝 Nhật ký cập nhật"] = "📝 Log de atualizações",
        ["Nhật ký cập nhật"] = "Log de atualizações",
      })
    end

    local useLang = "vi"
    pcall(function() useLang = HzUiLang() end)

    TabAbout:CreateDivider({ text = "Nhật ký cập nhật" })
    TabAbout:CreateSection("Nhật ký cập nhật")
    local con = TabAbout:CreateConsole({ Name = "Nhật ký cập nhật", Height = 220, Follow = false, MaxLines = 300 })
    for _, rel in ipairs(CHANGELOG) do
      con:Append("[" .. rel.ver .. (rel.date and (" · " .. rel.date) or "") .. "]")
      for _, it in ipairs(rel.items) do
        con:Append("[" .. it[1] .. "] " .. ((useLang == "en" and it[3]) or (useLang == "pt" and (it[4] or it[3])) or it[2]))
      end
    end
  end

  local taglines = {
    "✨ H — script gọn, chạy mượt",
    "🚀 Tự nhận game, nạp đúng script",
    "🎵 Có sẵn trình phát nhạc trong menu",
    "💾 Lưu script, đồng bộ sang máy khác",
    "🛡️ Anti-AFK, tăng FPS, dọn chat",
  }

  HiulzFW.Register("LiveInfo", {
    Title = "Thông tin trực tiếp",
    Priority = 10,
    Interval = 1,

    Init = function(self)
      self._i = 0
    end,

    Tick = function(self)
      setLbl(HelloLabel, "👋 " .. greeting() .. ", " .. _G.HzDisplayName() .. "!")
      setLbl(TaglineLabel, LS(taglines[(math.floor(self._i / 3) % #taglines) + 1]))
      local cnt, max = 0, 0
      pcall(function() cnt, max = #Players:GetPlayers(), Players.MaxPlayers end)
      setLbl(SrvLabel, string.format("👥 %d/%d %s", cnt, max, LS("người chơi")))
      setLbl(SrvTimeLabel, "⏱️ " .. LS("Server chạy: ") .. hms(workspace.DistributedGameTime))
      local used = getMem()
      pcall(function()
        RamProg:Set(used)
        local warn = RamProg:GetPercentage() >= 0.9
        if warn then RamProg:SetText(string.format("⚠ %d MB", used)) elseif self._ramWarn then RamProg:SetText() end
        self._ramWarn = warn
      end)
      setLbl(GameLabel, gameText())
      setLbl(VerLabel, verText())
      setLbl(ClockLabel, "🕒 " .. os.date("%H:%M:%S"))
      local up = tick() - _G.sT1
      setLbl(UptimeLabel, "⏳ " .. string.format(LS("Chạy được: %02d:%02d:%02d"), math.floor(up / 3600), math.floor((up % 3600) / 60), math.floor(up % 60)))
      self._i = self._i + 1
    end,

    Destroy = function(self)
      if self._hb then self._hb:Disconnect() self._hb = nil end
    end,
  })

  -- Chào mừng một lần khi vào script
  if _G.HzPerfLvl == "high" then task.delay(1.2, function() Confetti(28) end) end -- [PERF] confetti chào mừng chỉ HIGH
end

-- ===== TABS & BUTTONS =====
if HzG.isJJS then
  local TabJJS = Window:CreateTab("JJS Menu", tonumber("88421894421545"))
  _G.feb30fee1c45c6a5e(TabJJS, "jjs")
end

if HzG.isTSB then
  local TabTSB = Window:CreateTab("TSB Menu", tonumber("92607990285302"))
  _G.feb30fee1c45c6a5e(TabTSB, "tsb")

  local TabTech = Window:CreateTab("Tech", tonumber("17313313998"))
  _G.feb30fee1c45c6a5e(TabTech, "tsb_tech")

  local TabNhanVat = Window:CreateTab("Nhân Vật", tonumber("102043684127251"))
  _G.feb30fee1c45c6a5e(TabNhanVat, "tsb_character")
end

-- [TAB BLOX FRUIT]
if HzG.isBloxFruit then
  local TabBF = Window:CreateTab("Blox Fruit", tonumber("15370410333"))
  TabBF:CreateSection("Chức năng")
  local BFSearchInput
  BFSearchInput = TabBF:CreateInput({
    Name = "  Tìm script",
    PlaceholderText = "Tên hub, rồi Enter",
    Callback = function(Text)
      local filter = string.lower(tostring(Text or ""))
      pcall(function()
        TabBF:RestoreOrder()
        if filter == "" then
          for _, it in ipairs(TabBF._order) do
            if it.kind == "button" and it.handle:IsLocked() then it.handle:Unlock() end
          end
          return
        end
        local matched = {}
        for _, it in ipairs(TabBF._order) do
          if it.kind == "button" then
            if string.find(string.lower(it.name), filter, 1, true)
              or string.find(string.lower(tostring(_G.tR9(it.name))), filter, 1, true) then
              if it.handle:IsLocked() then it.handle:Unlock() end
              table.insert(matched, it)
            else
              it.handle:Lock("Không khớp từ khoá tìm kiếm")
            end
          end
        end
        for i = #matched, 1, -1 do matched[i].handle:MoveToTop() end
        if BFSearchInput then BFSearchInput:MoveToTop() end
      end)
    end
  })

  _G.f8eefa956e6130f83 = false
  TabBF:CreateToggle({
    Name = "   Chế độ copy script",
    CurrentValue = false,
    Callback = function(Value)
      _G.f8eefa956e6130f83 = Value
      if Value then
        local count = _G.e37669d62d5f58e0d or 0
        if count >= 3 then
          SafeNotify("Cài đặt", " Đã bật nhưng hết lượt copy!")
        else
          SafeNotify("Cài đặt", " Đã bật: bấm nút để copy (" .. (3 - count) .. " lượt còn)")
        end
            else
        SafeNotify("Cài đặt", " Đã tắt: bấm nút để chạy luôn")
      end
    end
  })
  _G.HzLazyTab(TabBF, "Blox Fruit", function() -- [PERF] danh sách nút Blox Fruit chỉ dựng khi mở tab lần đầu
  _G.feb30fee1c45c6a5e(TabBF, "blox_fruit_1")
  TabBF:CreateButton({
    Name = "Ohofo Banana",
    Callback = function()
getgenv().Key = "XyZpQrStUvWxYzAbCdEfGhIjKl"
      safeLoad("Ohofo Banana", "https://raw.githubusercontent.com/Ohofo2279/Premium/refs/heads/main/BF-BananaCat.lua")
    end
  })
  _G.feb30fee1c45c6a5e(TabBF, "blox_fruit_2")
  TabBF:CreateButton({
    Name = "Rise Hub",
    Callback = function()
      getgenv().Team = "Pirates" --Marines / Pirates
      safeLoad("Rise Hub", "https://raw.githubusercontent.com/asher-realrise/project/refs/heads/main/loadder.lua")
    end
  })
  _G.feb30fee1c45c6a5e(TabBF, "blox_fruit_3")
TabBF:CreateButton({
    Name = "Xeter V4",
    Callback = function()
      getgenv().Version = "V4"
      getgenv().Team = "Marines"
      safeLoad("Xeter V4", "https://raw.githubusercontent.com/TlDinhKhoi/Xeter/refs/heads/main/Main.lua")
    end
  })
  _G.feb30fee1c45c6a5e(TabBF, "blox_fruit_4")
  end) -- [PERF] hết HzLazyTab Blox Fruit

  -- Tab Linh Tinh (Auto Farm)
  local TabLT = Window:CreateTab("Auto Farm", tonumber("7508442970"))
  _G.HzLazyTab(TabLT, "Auto Farm", function() -- [V35]
  TabLT:CreateSection("Farm Bounty")
  TabLT:CreateButton({
    Name = "Vexeze Hub (Farm Bounty)",
    Callback = function()
      repeat task.wait() until game:IsLoaded()
      getgenv().LoadUi = true
      getgenv().LowGpu = false -- Fps Boost
      getgenv().Premium = false -- if false for free but true for premium and need key
      getgenv().Key = "" -- Your Key
      getgenv().Team = "Pirates" -- Marines
      getgenv().Mode = "M1 Fruit" -- Normal But Config In Discord
      getgenv().Studio = {
        ["Player Setting"] = {
          ["Camera Lock"] = false,
          ["Custom Pos Y"] = {["Enabled"] = true, ["Pos Y"] = 5000},
          ["Health Setting"] = {40, 50}, -- 40-50% Heath
          ["Set Bounty"] = {["Min"] = 0, ["Max"] = 30000000},
          ["Spam Dash"] = true,
          ["Your Fruit"] = "" -- Your Fruit Have M1
        },
        ["Target Setting"] = {
          ["Destroy Ken Target"] = false,
          ["Hunter Method"] = {
            ["Dogde Skill Target"] = true,
            ["Use Move Predict"] = true
          }
        }
      }
      getgenv().Webhook = {
        ["Enable"] = false,
        ["Url"] = ""
      }
      getgenv().HunterGui = {
        ["Hide_Gui"] = false,
        ["Setting"] = {["Gui"] = {}}
      }
      safeLoad("Vexeze Hub", "https://raw.githubusercontent.com/Dex-Bear/VxezeHubLoader/refs/heads/main/BF-HunterBounty.lua")
    end
  })

  TabLT:CreateButton({
    Name = "Night Hub (Farm Bounty)",
    Callback = function()
      getgenv().Config = {
        Team = "Pirates",
        HuntConfig = {
          ["Earned Notification Enabled"] = true,
          ["Farm Delay"] = 0.22, -- 0.15 Fast | 0.22 Fast | 0.35 Medium
          ["Webhook"] = {
            Enabled = false,
            Url = ""
          }
        }
      }
      safeLoad("Night Hub", "https://api.luarmor.net/files/v4/loaders/2ffcdb62773f587bfb9eb0d52bb35b0c.lua")
    end
  })

  TabLT:CreateButton({
    Name = "Dragonhub [Auto Farm Bounty] ",
    Callback = function()
      repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer
      getgenv().Setting = {
        ["Team"] = "Pirates",
        ["Auto Click"] = true,
        ["Delay Click"] = 0.3,
        ["EnableWeapon"] = {
          ["Fruit"] = false,
          ["Melee"] = true,
          ["Sword"] = true,
          ["Gun"] = false
        },
        ["Melee"] = {
          ["Z"] = {["Enable"] = true, ["HoldTime"] = 0.5},
          ["X"] = {["Enable"] = true, ["HoldTime"] = 0.6},
          ["C"] = {["Enable"] = true, ["HoldTime"] = 0.5},
          ["ChangeDelay"] = 3
        },
        ["Sword"] = {
          ["Z"] = {["Enable"] = true, ["HoldTime"] = 1.5},
          ["X"] = {["Enable"] = true, ["HoldTime"] = 0.6},
          ["ChangeDelay"] = 2
        },
        ["Gun"] = {
          ["Z"] = {["Enable"] = true, ["HoldTime"] = 0.1},
          ["X"] = {["Enable"] = true, ["HoldTime"] = 0.1},
          ["ChangeDelay"] = 1,
          ["GunMode"] = false
        },
        ["Fruit"] = {
          ["Z"] = {["Enable"] = true, ["HoldTime"] = 0.1},
          ["X"] = {["Enable"] = true, ["HoldTime"] = 0.1},
          ["C"] = {["Enable"] = true, ["HoldTime"] = 0.1},
          ["V"] = {["Enable"] = false, ["HoldTime"] = 0.1},
          ["F"] = {["Enable"] = true, ["HoldTime"] = 0.1},
          ["ChangeDelay"] = 1
        },
        ["LockBounty"] = {
          ["Enable"] = false,
          ["Min"] = 0,
          ["Max"] = 30000000
        },
        ["Skip"] = {
          ["Fruit"] = true,
          ["FruitSkip"] = {"Buddha","Tiger","T-Rex"},
          ["SafeZone"] = true,
          ["NoHaki"] = true,
          ["NoPvP"] = true
        },
        ["SafeHealth"] = {
          ["Health"] = 4700,
          ["Mask"] = false,
          ["MaskType"] = "Mask",
          ["RaceV4"] = false
        },
        ["Setting"] = {
          ["UseRaceV3"] = true,
          ["UseRaceV4"] = true,
          ["SafeHealth"] = true,
          ["Skip V4 Race"] = true,
          ["Health"] = 4700,
          ["FPSBoots"] = true,
          ["AutoServerHop"] = true,
          ["CheckCombatBeforeHop"] = true,
          ["Fast Attack"] = true
        },
        ["Select Region"] = {
          ["Enabled"] = true,
          ["Region"] = {
            ["Singapore"] = true,
            ["United States"] = false,
            ["Netherlands"] = false,
            ["Germany"] = false,
            ["India"] = false,
            ["Australia"] = false
          }
        },
        ["Webhook"] = {
          ["Enabled"] = true,
          ["Url"] = "your Url webhook"
        },
        ["AimBot"] = {
          ["Enable"] = true,
          ["AimCamera"] = {["Enable"] = true, ["MaxDistance"] = 300},
          ["LockAim"] = {["Enable"] = true}
        }
      }
      safeLoad("Vexeze Hub", "https://raw.githubusercontent.com/dragonhubdev/dragonwitheveryone/refs/heads/main/AutoBounty.lua")
    end
  })
  TabLT:CreateButton({
    Name = "Dragon AutoBounty",
    Callback = function()
getgenv().Config_Dragon = {
 ["Team"] = "Pirates",

 ["Race"] = {
 ["V3"] = true,
 ["V4"] = true
 },

 ["Weapons"] = {
 ["Fruit"] = {
 ["Enabled"] = true,
 ["ChangeDelay"] = 0.1,

 ["X"] = { ["Enabled"] = false, ["HoldTime"] = 0 },
 ["Z"] = { ["Enabled"] = false, ["HoldTime"] = 0 },
 ["C"] = { ["Enabled"] = false, ["HoldTime"] = 0 },
 ["V"] = { ["Enabled"] = false, ["HoldTime"] = 0 }
 }
 },

 ["Misc"] = {
 ["Fast Attack"] = true,

 ["Webhook"] = {
 ["Enabled"] = true,
 ["Url"] = "",
 ["Ping"] = "<@>",
 ["Delay"] = 40
 },

 ["MaxTargetDistance"] = 50000
 },

 ["Skip"] = {
 ["Fruit"] = true,
 ["FruitSkip"] = { "Buddha", "Yeti", "Portal" }
 }
}
      safeLoad("Dragon AutoBounty", "https://raw.githubusercontent.com/dragonhubdev/dragonwitheveryone/refs/heads/main/M1AutoBounty")
    end
  })
  TabBF:CreateButton({
    Name = "SynTrax AutoBounty",
    Callback = function()
      getgenv().Setting = {
    ["Team"] = "Pirates",
    ["Chat"] = {},
    ["Skip Race V4"] = true,
    ["Melee"] = {
      ["Enable"] = true,
      ["Z"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["X"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["C"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["Delay"] = 1.5
    },
    ["Sword"] = {
      ["Enable"] = true,
      ["Z"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["X"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["Delay"] = 1
    },
    ["Gun"] = {
      ["Enable"] = true,
      ["Z"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["X"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["Delay"] = 1,
      ["GunMode"] = false
    },
    ["Fruit"] = {
      ["Enable"] = true,
      ["Z"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["X"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["C"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["V"] = {["Enable"] = false, ["HoldTime"] = 0.1},
      ["F"] = {["Enable"] = true, ["HoldTime"] = 0.1},
      ["Delay"] = 1
    },
    ["Hunt"] = {
      ["Min"] = 0,
      ["Max"] = 30000000
    },
    ["Skip"] = {
      ["Fruit"] = false,
      ["FruitList"] = {"Buddha", "Leopard", "T-Rex"},
      ["SafeZone"] = true,
      ["NoHaki"] = true,
      ["NoPvP"] = true
    },
    ["SafeHealth"] = {
      ["Health"] = 4700,
      ["Mask"] = false,
      ["MaskType"] = "Mask",
      ["RaceV4"] = false
    },
    ["Another"] = {
      ["V3"] = true,
      ["V4"] = true,
      ["CustomHealth"] = true,
      ["Health"] = 4700,
      ["WhiteScreen"] = false,
      ["FPSBoots"] = false,
      ["AutoServerHop"] = true,
      ["HopWhenNoBounty"] = true,
      ["BountyLock"] = false,
      ["BountyLockAt"] = 30000000,
      ["ServerHopAfterTime"] = false,
      ["ServerHopTime"] = 900,
      ["CheckCombatBeforeHop"] = true,
      ["MaxPlayersInServer"] = 8
    },
    ["Webhook"] = {
      ["Enabled"] = false,
      ["Url"] = ""
    }
}
      safeLoad("SynTrax AutoBounty", "https://raw.githubusercontent.com/DevHub-roblox/script-SYNTRAX-Hub/refs/heads/main/SynTrax-Auto-bounty")
    end
  })
TabLT:CreateSection("Farm Chest")
  TabLT:CreateButton({
    Name = "Lone Hub Chest",
    Callback = function()
      getgenv().Team = "Pirates" -- Pirates, Marines
      getgenv().Setting = {
        ["White Screen"] = false,
        ["Black Screen"] = false,
        ["Boost Fps"] = false,
        ["Lock Fps"] = {
          ["Enabled"] = false,
          ["Fps"] = 20,
        },
        ["Auto Chat"] = {
          ["Enabled"] = true,
          ["Text"] = "Lonely Hub On Top",
          ["Delay"] = 150,
        },
      }
      safeLoad("Lone Hub Chest", "https://raw.githubusercontent.com/LongHip12/LonelyHub/refs/heads/main/LonelyHub-FarmChestBF.lua")
    end
  })
  _G.feb30fee1c45c6a5e(TabLT, "auto_farm_1")
  TabLT:CreateButton({
    Name = "Auto 39 Quests Kaitun",
    Callback = function()
      repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer
      getgenv().Key = "VIP-7943-C73D-4D3C"
      getgenv().Auto39QuestsConfig = getgenv().Auto39QuestsConfig or {
        ["Enabled"] = true,
        ["Auto Secret Quest"] = true,
        ["Hidden Hop Dead Hour"] = true,
        ["Bring Mob"] = true,
        ["Select Weapon"] = "Melee", -- "Melee", "Sword", "Blox Fruit"
        ["AutoEquipWeapon"] = "Melee",
        ["Attack No Animation "] = true,
        ["Speed Tween"] = 210,
        ["FastAttack"] = true,
        ["SafeDistanceY"] = 25,
        ["AutoBusohaki"] = true,
      }

      if not game:IsLoaded() then game.Loaded:Wait() end
      local lp = game:GetService("Players").LocalPlayer
      if not lp then
        game:GetService("Players").PlayerAdded:Wait()
        lp = game:GetService("Players").LocalPlayer
      end
      if not lp.Character then
        task.spawn(function()
          while not lp.Character do
            pcall(function()
              game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("SetTeam", "Pirates")
            end)
            task.wait(1)
          end
        end)
        lp.CharacterAdded:Wait()
      end
      safeLoad("Auto 39 Quests Kaitun", "https://raw.githubusercontent.com/hihiae/36var/refs/heads/main/lonmemayluon.lua")
    end
  })
  TabLT:CreateButton({
    Name = "3TN Kaitun",
    Callback = function()
      getgenv().Config = {
        Team = "Pirates",
        Configuration = {
          HopWhenIdle = true,
          AutoHop = true,
          AutoHopDelay = 60 * 60,
          FpsBoost = true,
          blackscreen = false
        },
        Items = {
          AutoFullyMelees = true,
          Saber = true,
          CursedDualKatana = false,
          SoulGuitar = false,
          RaceV2 = true
        },
        Settings = {
          StayInSea2UntilHaveDarkFragments = false
        }
      }
      safeLoad("3TN Kaitun", "https://raw.githubusercontent.com/sucvatthieunang/djtme/refs/heads/main/module")
    end
  })
  TabLT:CreateButton({
    Name = "OkHubKaitun",
    Callback = function()
getgenv().SettingFarm ={
    ["Reset Teleport"] = {
      ["Enabled"] = false,
      ["Delay Reset"] = 3,
      ["Item Dont Reset"] = {
        ["Fruit"] = {
          ["Enabled"] = true,
          ["All Fruit"] = true,
          ["Select Fruit"] = {
            ["Enabled"] = false,
            ["Fruit"] = {},
          },
        },
      },
    },
    ["White Screen"] = false,
    ["Lock Fps"] = {
      ["Enabled"] = true,
      ["FPS"] = 360,
    },
    ["Get Items"] = {
      ["Saber"] = true,
      ["Godhuman"] =  true,
      ["Skull Guitar"] = true,
      ["Mirror Fractal"] = true,
      ["Cursed Dual Katana"] = true,
      ["Upgrade Race V2-V3"] = true,
      ["Auto Pull Lever"] = true,
      ["Shark Anchor"] = true, cdk,sg,godhuman
    },
    ["Get Rare Items"] = {
      ["Rengoku"] = false,
      ["Dragon Trident"] = false,
      ["Pole (1st Form)"] = false,
      ["Gravity Blade"]  = false,
    },
    ["Farm Fragments"] = {
      ["Enabled"]  = false,
      ["Fragment"] = 50000,
    },
    ["Auto Chat"] = {
      ["Enabled"] = true,
      ["Text"] = "Ok Hub Kaitun BF",
    },
    ["Auto Summon Rip Indra"] = true,
    ["Select Hop"] = {
      ["Hop Server If Have Player Near"] = false,
      ["Hop Find Rip Indra Get Valkyrie Helm or Get Tushita"] = true,
      ["Hop Find Dough King Get Mirror Fractal"] = false,
      ["Hop Find Raids Castle [CDK]"] = true,
      ["Hop Find Cake Queen [CDK]"] = true,
      ["Hop Find Soul Reaper [CDK]"] = true,
      ["Hop Find Darkbeard [SG]"] = true,
      ["Hop Find Mirage [ Pull Lever ]"] = false,
    },
    ["Farm Mastery"] = {
      ["Melee"] = false,
      ["Sword"] = false,
    },
    ["Buy Haki"] = {
      ["Enhancement"] = false,
      ["Skyjump"] = true,
      ["Flash Step"] = true,
      ["Observation"] = true,
    },
  }
      safeLoad("OkHubKaitun", "https://raw.githubusercontent.com/fakekuri/Okhubhere/refs/heads/main/KaitunBloxFruit.lua")
    end
  })
TabLT:CreateButton({
    Name = "Meox Hub Kaitun",
    Callback = function()
    getgenv().Config = {
  Team = "Pirates",
  FarmConfig = {
    ["Out game when done all"] = true,
    ["Bypass Teleport"] = true,
    ["Double Quest(RISK)"] = true
  },
  Items = {
    ["Saber"] = true,
    ["Pole (1st form)"] = true,
    ["Skull Guitar"] = true,
    ["Cursed Dual Katana"] = true,
    ["Godhuman"] = true
  },
  Webhook = {
    ["Enabled"] = false,
    ["Url"] = ""
  }
}
      safeLoad("Meox Hub Kaitun", "https://api.luarmor.net/files/v4/loaders/d6c7959dcc94cd24467080d82a56dcf9.lua")
    end
  })
  _G.feb30fee1c45c6a5e(TabLT, "auto_farm_2")
  end) -- [V35]
end

if HzG.isJumpShowdown then
  local TabJS = Window:CreateTab("Jump Showdown", tonumber("92616478061584"))
  TabJS:CreateSection("Jump Showdown")

  TabJS:CreateButton({
    Name = "Copy script",
    Callback = function()
      local scriptText = [[script_key="ur key here"
loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/01868f68b39e5d2e8e789d97b050ee07.lua"))()
KEY : https://ads.luarmor.net/get_key?for=Kitsu_Key_Access-EDECddRlqemy]]
      local ok = CopyToClipboardSafe(scriptText)
      if ok then
        NotifySafe("Thành công", " Đã sao chép Script Jump Showdown vào clipboard. Dán vào Executor (Ctrl+V).")
      else
        NotifySafe("Lỗi", "Executor/ môi trường không hỗ trợ setclipboard. Link đã được hiển thị trong console.")
        print("Script (copy manually):\n" .. scriptText)
      end
    end
  })

  _G.feb30fee1c45c6a5e(TabJS, "jump_showdown")
end

if HzG.isEscapeTsunami then
  local TabTsunami = Window:CreateTab("Tsunami Brainrots", tonumber("11200248810"))
  _G.feb30fee1c45c6a5e(TabTsunami, "escape_tsunami")
end

-- [TAB FISH IT]
if HzG.isFishIt then
  local TabFishIt = Window:CreateTab("Fish It", tonumber("81795620397244"))
  _G.feb30fee1c45c6a5e(TabFishIt, "fish_it")
end

-- [TAB FISH - CHỈ HIỂN THỊ Ở GAME FISH]
if HzG.isFish then
  local TabFish = Window:CreateTab("Fish", tonumber("81795620397244"))
  _G.feb30fee1c45c6a5e(TabFish, "fish")
end

-- [TAB MM2 - CHỈ HIỂN THỊ Ở GAME MURDER MYSTERY 2]
if HzG.isMM2 then
  local TabMM2 = Window:CreateTab("MM2 Menu", tonumber("15142787703"))
  _G.feb30fee1c45c6a5e(TabMM2, "mm2")
end

-- [TAB GARDEN HORIZONS]
if HzG.isGardenHorizons then
  local TabGarden = Window:CreateTab("Garden Horizons", tonumber("99618226040648"))
  _G.feb30fee1c45c6a5e(TabGarden, "garden_horizons_1")
  TabGarden:CreateButton({
    Name = "BlueX-Hub",
    Callback = function()
      _G.AutoTranslate = true
      _G.SaveConfig = true
      safeLoad("BlueX-Hub", "https://raw.githubusercontent.com/Dev-BlueX/BlueX-Hub/refs/heads/main/Main.lua")
    end
  })
  _G.feb30fee1c45c6a5e(TabGarden, "garden_horizons_2")
end

if HzG.isEvadeGame then
  local TabEvade = Window:CreateTab("Evade", tonumber("98194683460296"))
  _G.feb30fee1c45c6a5e(TabEvade, "evade_1")
  TabEvade:CreateButton({
    Name = "DP HUB-Keyless",
    Callback = function()
      safeLoadSmart("DP HUB ", "\108\111\97\100\115\116\114\105\110\103\40\103\97\109\101\58\72\116\116\112\71\101\116\40\34\104\116\116\112\115\58\47\47\114\97\119\46\103\105\116\104\117\98\117\115\101\114\99\111\110\116\101\110\116\46\99\111\109\47\67\79\79\76\88\80\76\79\47\68\80\45\72\85\66\45\99\111\111\108\120\112\108\111\47\114\101\102\115\47\104\101\97\100\115\47\109\97\105\110\47\69\118\97\100\101\46\108\117\97\34\41\41\40\41")
    end
  })
  _G.feb30fee1c45c6a5e(TabEvade, "evade_2")
  TabEvade:CreateButton({
    Name = "Evade Auto Farm Script (NO KEY)",
    Callback = function()
    getgenv().farm = false -- false/true
      safeLoadSmart("Evade Auto Farm Script (NO KEY)", "https://raw.githubusercontent.com/Bac0nHck/Scripts/refs/heads/main/evade-farm.lua")
    end
  })
  _G.feb30fee1c45c6a5e(TabEvade, "evade_3")
end

-- [TAB DOORS]
if HzG.isDoors then
  local TabDoors = Window:CreateTab("Doors", tonumber("12209991869"))
  _G.feb30fee1c45c6a5e(TabDoors, "doors")
end

if HzG.is99Nights then
  local ForestTab = Window:CreateTab("99 Nights", tonumber("125094830280177"))
  _G.feb30fee1c45c6a5e(ForestTab, "99_nights")
end

if HzG.isKnockout then
  local KnockoutTab = Window:CreateTab("Knockout!", tonumber("4549964420"))
  _G.feb30fee1c45c6a5e(KnockoutTab, "knockout")
end

if HzG.isTitanFishing then
  local TitanTab = Window:CreateTab("Titan-Fishing", tonumber("104623054699018"))
  _G.feb30fee1c45c6a5e(TitanTab, "titan_fishing")
end

if HzG.isStealAnEgg then
  local StealEggTab = Window:CreateTab("Steal an Egg", tonumber("135305490825675"))
  _G.feb30fee1c45c6a5e(StealEggTab, "steal_an_egg")
end

if HzG.isKingLegacy then
  local KingLegacyTab = Window:CreateTab("King Legacy", tonumber("83280537222407"))
  _G.feb30fee1c45c6a5e(KingLegacyTab, "king_legacy")
end

-- [TAB TIỆN ÍCH] - khi không rơi vào game đặc biệt
if not HzG.any then
  local TabUtility = Window:CreateTab("Script", tonumber("11570895459"))
  TabUtility:CreateLabel([[Game chưa hỗ trợ. Xem script chung ở tab Khác.]])
end

local TabChung = Window:CreateTab("Khác", tonumber("5704671379"))
_G.feb30fee1c45c6a5e(TabChung, "general")
-- Lấy danh sách script qua API công khai của ScriptBlox (fetch / search). Script chỉ chạy khi người dùng bấm nút.
-- Toàn bộ nằm trong pcall(function() ... end) để không tăng số local của chunk và để lỗi ở đây không ảnh hưởng tab khác.
do
  local okSB, errSB = pcall(function()
    local HttpService = game:GetService("HttpService")
    local L = _G.tR9 or function(s) return s end
    local LU = HzUiS or L -- chữ :Set() theo ngôn ngữ UI đang hiển thị

    local SB_BASE = "https://scriptblox.com"
    local PAGE_MAX, CACHE_TTL, CACHE_LIMIT = ((_G.HzConst or {}).scriptblox or {}).pageMax or 20, ((_G.HzConst or {}).scriptblox or {}).cacheTTL or 300, ((_G.HzConst or {}).scriptblox or {}).cacheLimit or 40
    local ICON_TAB = tonumber("91576819874861")
    local ICON_VERIFIED = tonumber("136096001067548")
    local ICON_KEY = tonumber("5060864302")
    local U = type(utf8) == "table" and utf8 or nil

    -- Cache tạm trong _G (hết hạn sau CACHE_TTL giây) để tránh gọi API quá nhiều
    if type(_G.HzSBCache) ~= "table" then _G.HzSBCache = {} end
    local Cache = _G.HzSBCache

    local SB_FILE, SB_DIR, SB_KEEP = "x8k2/sb_cache.json", "x8k2", 8
    local sbFS = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"
    local sbLoaded = false
    local function sbDiskLoad()
      if sbLoaded then return end
      sbLoaded = true
      if not sbFS then return end
      pcall(function()
        if not isfile(SB_FILE) then return end
        local d = HttpService:JSONDecode(readfile(SB_FILE))
        if type(d) ~= "table" or type(d.entries) ~= "table" then return end
        for url, c in pairs(d.entries) do
          if type(url) == "string" and Cache[url] == nil and type(c) == "table" and type(c.t) == "number"
            and type(c.data) == "table" and type(c.data.scripts) == "table" and os.time() - c.t < CACHE_TTL then
            Cache[url] = c
          end
        end
      end)
    end
    local function sbDiskSave()
      if not sbFS then return end
      pcall(function()
        local arr = {}
        for url, c in pairs(Cache) do
          if os.time() - c.t < CACHE_TTL then arr[#arr + 1] = { url = url, c = c } end
        end
        table.sort(arr, function(a, b) return a.c.t > b.c.t end)
        local entries = {}
        for i = 1, math.min(#arr, SB_KEEP) do
          local c, scripts = arr[i].c, {}
          for j, it in ipairs(c.data.scripts) do
            local cp = {}
            for k, v in pairs(it) do if k ~= "inline" then cp[k] = v end end -- bỏ mã nhúng cho file nhỏ
            scripts[j] = cp
          end
          entries[arr[i].url] = { t = c.t, data = { page = c.data.page, totalPages = c.data.totalPages, nextPage = c.data.nextPage, scripts = scripts } }
        end
        if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(SB_DIR) then makefolder(SB_DIR) end
        writefile(SB_FILE, HttpService:JSONEncode({ version = 1, entries = entries }))
      end)
    end

    local S = {
      page = 1, total = 1, query = "", activeQuery = "",
      items = {}, map = {}, opts = {}, sel = nil,
      loading = false, queued = nil, started = false, token = 0,
      fVer = false, fNoKey = false, fUni = false,
      confirmSlug = nil, confirmUntil = 0,
    }
    local Tab, ProgBar, StatusLabel, Dropdown, DetailLabel
    local loadPage

    local function log(msg, lvl) if _G.aa3542001e064bc52 then _G.aa3542001e064bc52(msg, lvl) end end
    local function say(msg) SafeNotify("ScriptBlox", msg) end

    ----------------------------------------------------------------
    -- Tiện ích chuỗi
    ----------------------------------------------------------------
    local function clean(v, n)
      local s = tostring(v == nil and "" or v)
      s = s:gsub("%c", " ")
      s = s:gsub("%s+", " ")
      s = s:match("^%s*(.-)%s*$") or s
      if n and n > 0 then
        if U then
          local okL, len = pcall(U.len, s)
          if okL and len then
            if len > n then
              local okO, off = pcall(U.offset, s, n + 1)
              if okO and off then s = s:sub(1, off - 1) .. "…" end
            end
          elseif #s > n * 3 then
            s = s:sub(1, n * 3)
          end
        elseif #s > n * 3 then
          s = s:sub(1, n * 3)
        end
      end
      return s
    end

    local function fmtNum(v)
      v = tonumber(v) or 0
      local s = tostring(math.floor(v + 0.5))
      s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
      s = s:gsub("^,", "")
      return s
    end

    local function dateStr(iso)
      local y, m, d, hh, mm = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+)")
      if not y then return "?" end
      return string.format("%s/%s/%s %s:%s UTC", d, m, y, hh, mm)
    end

    -- slug chỉ cho phép chữ/số/-._~ (không thể chèn dấu nháy vào loadstring)
    local function validSlug(s)
      return type(s) == "string" and #s > 0 and #s <= 300 and s:match("^[%w%-%._~]+$") ~= nil
    end

    ----------------------------------------------------------------
    -- HTTP (luôn bọc pcall, kiểm tra typeof(game.HttpGet) trước khi dùng)
    ----------------------------------------------------------------
    local function httpGet(url)
      local lastErr = "NO_HTTP"
      local okT, tName = pcall(function() return typeof(game.HttpGet) end)
      if okT and tName == "function" then
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        if ok and type(res) == "string" then return res end
        lastErr = tostring(res)
      end
      local okA, tAsync = pcall(function() return typeof(game.HttpGetAsync) end)
      if okA and tAsync == "function" then
        local ok, res = pcall(function() return game:HttpGetAsync(url) end)
        if ok and type(res) == "string" then return res end
        lastErr = tostring(res)
      end
      local req = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
        or nil
      if req then
        local ok, res = pcall(req, { Url = url, Method = "GET" })
        if ok and type(res) == "table" then
          local code = tonumber(res.StatusCode or res.statusCode)
          if (code == nil or (code >= 200 and code < 300)) and type(res.Body) == "string" then return res.Body end
          lastErr = "HTTP " .. tostring(code or "?")
        else
          lastErr = tostring(res)
        end
      end
      return nil, lastErr
    end

    local function buildUrl(page, query)
      local q = {}
      local base
      if query ~= "" then
        base = SB_BASE .. "/api/script/search"
        q[#q + 1] = "q=" .. HttpService:UrlEncode(query)
      else
        base = SB_BASE .. "/api/script/fetch"
        q[#q + 1] = "sortBy=createdAt"
        q[#q + 1] = "order=desc"
      end
      q[#q + 1] = "max=" .. PAGE_MAX
      q[#q + 1] = "page=" .. page
      q[#q + 1] = "mode=free"
      if S.fVer then q[#q + 1] = "verified=1" end
      if S.fNoKey then q[#q + 1] = "key=0" end
      if S.fUni then q[#q + 1] = "universal=1" end
      return base .. "?" .. table.concat(q, "&")
    end

    -- Chuẩn hoá 1 script trong response (title, gameName, slug, verified, key, views, scriptType, isPatched, ...)
    local function normalize(s)
      if type(s) ~= "table" then return nil end
      local g = type(s.game) == "table" and s.game or {}
      local title = clean(s.title, 90)
      local gameName = clean(g.name, 60)
      local stype = clean(s.scriptType, 12)
      local noExec = {}
      if type(s.noExec) == "table" then
        for _, v in ipairs(s.noExec) do noExec[#noExec + 1] = clean(v, 20) end
      end
      local keyLink
      if type(s.keyLink) == "string" and #s.keyLink <= 300 and s.keyLink:match("^https?://[%w%.%-_/%?=&#%%~:+@,;]+$") then
        keyLink = s.keyLink
      end
      return {
        title = title ~= "" and title or "?",
        gameName = gameName ~= "" and gameName or (s.isUniversal == true and "Universal" or "?"),
        slug = type(s.slug) == "string" and s.slug or "",
        verified = s.verified == true,
        key = s.key == true,
        views = tonumber(s.views) or 0,
        executes = tonumber(s.executes) or 0,
        scriptType = stype ~= "" and stype or "free",
        isUniversal = s.isUniversal == true,
        isPatched = s.isPatched == true,
        createdAt = tostring(s.createdAt or ""),
        keyLink = keyLink,
        noExec = noExec,
        inline = type(s.script) == "string" and s.script or nil,
      }
    end

    -- fetchScriptBlox(page, query, callback[, force]) -> callback(ok, result | lỗi, fromCache)
    -- result = { page, totalPages, nextPage, scripts = { {title, gameName, slug, verified, key, views, ...} } }
    local function fetchScriptBlox(page, query, callback, force)
      task.spawn(function()
        local function done(ok, res, cached) pcall(callback, ok, res, cached) end
        local okU, url = pcall(buildUrl, page, query or "")
        if not okU then return done(false, tostring(url)) end
        if not force then
          sbDiskLoad()
          local c = Cache[url]
          if c and os.time() - c.t < CACHE_TTL then return done(true, c.data, true) end
        end
        local body, err = httpGet(url)
        if not body then return done(false, err or "HTTP") end
        local okJ, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not okJ or type(data) ~= "table" then return done(false, "invalid response (JSON)") end
        local result = data.result
        if type(result) ~= "table" or type(result.scripts) ~= "table" then
          return done(false, clean(data.message or "no result", 80))
        end
        local out = {
          page = page,
          totalPages = math.max(1, math.floor(tonumber(result.totalPages) or 1)),
          nextPage = tonumber(result.nextPage),
          scripts = {},
        }
        for i, raw in ipairs(result.scripts) do
          if i > PAGE_MAX then break end
          local it = normalize(raw)
          if it then out.scripts[#out.scripts + 1] = it end
        end
        local n = 0
        for _ in pairs(Cache) do n = n + 1 end
        if n >= CACHE_LIMIT then for k in pairs(Cache) do Cache[k] = nil end end
        Cache[url] = { t = os.time(), data = out }
        sbDiskSave()
        return done(true, out, false)
      end)
    end

    ----------------------------------------------------------------
    -- Hiển thị
    ----------------------------------------------------------------
    local function labelFor(i, it)
      return string.format("%02d. %s%s🎮 %s - %s (👁 %s)", i,
        it.verified and "✅ " or "", it.key and "🔑 " or "",
        clean(it.gameName, 22), clean(it.title, 38), fmtNum(it.views))
    end

    local function rebuildOptions()
      S.map, S.opts = {}, {}
      for i, it in ipairs(S.items) do
        local lb = labelFor(i, it)
        S.map[lb] = i
        S.opts[#S.opts + 1] = lb
      end
      if #S.opts == 0 then S.opts = { LU("— Chưa có dữ liệu —") } end
    end

    local function selectedItem() return S.sel and S.items[S.sel] or nil end

    local function detailText(it)
      if not it then return LU("Chọn một script ở trên để xem chi tiết.") end
      local lines = {
        "📜 " .. LU("Tiêu đề: ") .. it.title,
        "🎮 " .. LU("Game: ") .. it.gameName .. (it.isUniversal and " (Universal)" or ""),
        "👁 " .. LU("Lượt xem: ") .. fmtNum(it.views) .. "   ⚡ " .. LU("Lượt chạy: ") .. fmtNum(it.executes),
        "🏷 " .. LU("Loại: ") .. it.scriptType .. (it.verified and "   ✅ Verified" or "") .. (it.key and "   🔑 Key" or "   🆓 No key"),
        "📅 " .. LU("Ngày tạo: ") .. dateStr(it.createdAt),
        "🔗 Slug: " .. it.slug,
      }
      if it.isPatched then lines[#lines + 1] = "⚠️ " .. LU("Script này có thể đã bị Patched.") end
      if #it.noExec > 0 then lines[#lines + 1] = "⚠️ " .. LU("Không chạy trên: ") .. table.concat(it.noExec, ", ") end
      if it.keyLink then lines[#lines + 1] = "🔑 " .. LU("Link lấy key: ") .. it.keyLink end
      return table.concat(lines, "\n")
    end

    local function updateDetail()
      if DetailLabel then pcall(function() DetailLabel:Set(detailText(selectedItem())) end) end
    end

    local function updateStatus()
      if not StatusLabel then return end
      local txt = string.format(LU("Trang %d/%d • %d script"), S.page, S.total, #S.items)
      if S.activeQuery ~= "" then txt = txt .. "  🔍 " .. S.activeQuery end
      pcall(function() StatusLabel:Set(txt) end)
    end

    ----------------------------------------------------------------
    -- Tải danh sách (có phân trang, trạng thái loading, hàng đợi khi bấm liên tục)
    ----------------------------------------------------------------
    loadPage = function(page, query, force)
      query = query or ""
      if S.loading then
        S.queued = { page, query, force }
        return
      end
      S.loading = true
      S.started = true
      pcall(function() ProgBar:SetRange(0, 1) end)
      pcall(function() ProgBar:SetIndeterminate(true) end)
      pcall(function() ProgBar:SetText(LU("Đang tải từ ScriptBlox...")) end)
      say(L("Đang tải từ ScriptBlox..."))
      fetchScriptBlox(page, query, function(ok, res)
        S.loading = false
        if ok then
          S.page, S.total, S.items, S.activeQuery = res.page, res.totalPages, res.scripts, query
          S.sel, S.confirmSlug = nil, nil
          rebuildOptions()
          if Dropdown then pcall(function() Dropdown:Refresh(S.opts, true) end) end
          updateDetail()
          updateStatus()
          pcall(function() ProgBar:SetIndeterminate(false) end)
          pcall(function() ProgBar:SetRange(0, math.max(1, S.total)) end)
          pcall(function() ProgBar:Set(S.page) end)
          pcall(function() ProgBar:SetText() end)
          if #S.items == 0 then
            say(L("Không có script nào phù hợp."))
          else
            say(string.format(L("Đã tải %d script (trang %d/%d)"), #S.items, S.page, S.total))
          end
          log("ScriptBlox: tải " .. #S.items .. " script (trang " .. S.page .. "/" .. S.total .. ")", "SUCCESS")
        else
          pcall(function() ProgBar:SetIndeterminate(false) end)
          pcall(function() ProgBar:SetRange(0, 1) end)
          pcall(function() ProgBar:Set(0) end)
          pcall(function() ProgBar:SetText(LU("Lỗi tải")) end)
          say("❌ " .. L("Không tải được dữ liệu từ ScriptBlox: ") .. clean(res, 80))
          log("ScriptBlox: lỗi tải - " .. tostring(res), "ERROR")
        end
        local q = S.queued
        S.queued = nil
        if q then task.defer(loadPage, q[1], q[2], q[3]) end
      end, force)
    end

    local function scheduleReload() -- đổi bộ lọc: tự tải lại trang đầu (chỉ khi đã tải ít nhất 1 lần)
      if not S.started then return end
      S.token = S.token + 1
      local my = S.token
      task.delay(0.6, function()
        if my == S.token then loadPage(1, S.query, false) end
      end)
    end

    ----------------------------------------------------------------
    -- Copy / Chạy (chỉ khi bấm nút)
    ----------------------------------------------------------------
    local function loaderFor(it) return 'loadstring(game:HttpGet("' .. SB_BASE .. "/raw/" .. it.slug .. '"))()' end

    -- Lấy mã thực thi: ưu tiên endpoint raw; nếu API fetch đã trả sẵn mã (không phải dạng loader) thì dùng luôn
    local function fetchCode(it)
      if it.inline and #it.inline > 0 and not it.inline:match("^%s*loadstring%s*%(%s*game:HttpGet") then
        return it.inline
      end
      local urls = { SB_BASE .. "/raw/" .. it.slug, SB_BASE .. "/api/script/raw/" .. it.slug }
      local lastErr
      for _, u in ipairs(urls) do
        local body, err = httpGet(u)
        if type(body) == "string" and #body > 0 then
          local head = body:sub(1, 200):lower()
          local bad = body == "404: Not Found" or body == "Not Found"
            or head:find("404 not found", 1, true) ~= nil
            or head:find("<!doctype", 1, true) ~= nil
            or head:find("<html", 1, true) ~= nil
            or head:find('{"message"', 1, true) == 1
          if not bad then return body end
          lastErr = "404 / invalid"
        else
          lastErr = err
        end
      end
      return nil, lastErr
    end

    local function copyItem(it)
      if not it then say(L("Chưa chọn script nào!")) return end
      if not validSlug(it.slug) then say(L("Slug không hợp lệ!")) return end
      local ok = pcall(function() setclipboard(loaderFor(it)) end)
      say(ok and L("Đã copy loadstring vào clipboard!") or L("Executor không hỗ trợ copy."))
    end

    local function runItem(it)
      if not it then say(L("Chưa chọn script nào!")) return end
      if not validSlug(it.slug) then say(L("Slug không hợp lệ!")) return end
      if _G.f8eefa956e6130f83 then -- chế độ "chỉ copy" ở Cài đặt: không chạy, chỉ copy loadstring
        copyItem(it)
        return
      end
      -- Script cần key / có thể đã Patched: bấm ▶ Chạy lần nữa trong 10 giây để xác nhận
      if (it.key or it.isPatched) and not (S.confirmSlug == it.slug and os.clock() < S.confirmUntil) then
        S.confirmSlug, S.confirmUntil = it.slug, os.clock() + 10
        local msg = it.key and L("Script này cần KEY! Bấm ▶ Chạy lần nữa để xác nhận.")
          or L("Script này có thể đã bị Patched! Bấm ▶ Chạy lần nữa để xác nhận.")
        if it.key and it.keyLink then msg = msg .. "\n🔑 " .. it.keyLink end
        say(msg)
        return
      end
      S.confirmSlug = nil
      if _G.HzAutoRestore then pcall(_G.HzAutoRestore.track, it.title, SB_BASE .. "/raw/" .. it.slug, "scriptblox") end
      say(L("Đang tải script..."))
      task.spawn(function()
        local code, err = fetchCode(it)
        if not code then
          say(L("❌ Không tải được mã script: ") .. clean(err or "?", 60))
          log("ScriptBlox: không lấy được mã " .. it.slug .. " - " .. tostring(err), "ERROR")
          _G.HzLogError("Không tải được mã: " .. tostring(err), "ScriptBlox: " .. it.title .. " (" .. it.slug .. ")")
          return
        end
        local fn, cerr = loadstring(code)
        if not fn then
          say(L("❌ Script bị lỗi cú pháp, không thể chạy!"))
          log("ScriptBlox: lỗi cú pháp " .. it.slug, "ERROR")
          _G.HzLogError("Lỗi cú pháp: " .. tostring(cerr), "ScriptBlox: " .. it.title .. " (" .. it.slug .. ")")
          return
        end
        local ok, e = pcall(fn)
        if ok then
          say(L("✅ Đã chạy: ") .. clean(it.title, 40))
          log("ScriptBlox: ran " .. it.slug, "SUCCESS")
        else
          say(L("Lỗi thực thi: ") .. clean(e, 80))
          log("ScriptBlox: run error " .. it.slug .. " - " .. tostring(e), "ERROR")
          _G.HzLogError(e, "ScriptBlox: " .. it.title .. " (" .. it.slug .. ")")
        end
      end)
    end

    ----------------------------------------------------------------
    -- Giao diện (tab nằm ngay sau tab "Khác")
    ----------------------------------------------------------------
    Tab = Window:CreateTab("ScriptBlox", ICON_TAB)
    _G.HzLazyTab(Tab, "ScriptBlox", function() -- [V35]

    Tab:CreateDivider({ text = "Nguồn: ScriptBlox.com" })
    Tab:CreateSection("Nguồn: ScriptBlox.com")
    Tab:CreateLabel("ℹ️ Script do cộng đồng ScriptBlox đăng tải, không phải của HiulzHub. Hãy cân nhắc trước khi chạy — script chỉ chạy khi bạn bấm ▶ Chạy.")

    Tab:CreateDivider({ text = "Tìm kiếm" })
    Tab:CreateSection("Tìm kiếm")
    Tab:CreateInput({
      Name = "Tìm kiếm",
      PlaceholderText = "Tìm script trên ScriptBlox...",
      RemoveTextAfterFocusLost = false,
      Callback = function(t) S.query = clean(t, 80) end,
    })
    Tab:CreateButton({
      Name = "Tìm",
      Callback = function() loadPage(1, S.query, false) end,
    })
    Tab:CreateButton({
      Name = "Tải lại",
      Callback = function() loadPage(1, S.query, true) end,
    })

    Tab:CreateDivider({ text = "Bộ lọc" })
    Tab:CreateSection("Bộ lọc")
    Tab:CreateToggle({
      Name = "Chỉ script đã xác minh (Verified)",
      Icon = ICON_VERIFIED,
      CurrentValue = false,
      Callback = function(v) S.fVer = v == true; scheduleReload() end,
    })
    Tab:CreateToggle({
      Name = "Chỉ script không cần key",
      Icon = ICON_KEY,
      CurrentValue = false,
      Callback = function(v) S.fNoKey = v == true; scheduleReload() end,
    })
    Tab:CreateToggle({
      Name = "Chỉ script đa năng (Universal)",
      CurrentValue = false,
      Callback = function(v) S.fUni = v == true; scheduleReload() end,
    })

    Tab:CreateDivider({ text = "Danh sách script" })
    Tab:CreateSection("Danh sách script")
    ProgBar = Tab:CreateProgress({ name = "Tiến trình tải ScriptBlox", range = { 0, 1 }, value = 0, text = "—", format = HzFmtN })
    StatusLabel = Tab:CreateLabel("Bấm Tải lại để tải danh sách script mới nhất.")
    rebuildOptions()
    Dropdown = Tab:CreateDropdown({
      Name = "Chọn script",
      Options = S.opts,
      CurrentOption = { S.opts[1] },
      MultipleOptions = false,
      Callback = function(sel)
        local v = sel and sel[1]
        S.sel = (v and S.map[v]) or nil
        S.confirmSlug = nil
        updateDetail()
      end,
    })
    Tab:CreateButton({
      Name = "Trang trước",
      Callback = function()
        if not S.started then loadPage(1, S.query, false) return end
        if S.page <= 1 then say(L("Đang ở trang đầu.")) return end
        loadPage(S.page - 1, S.activeQuery, false)
      end,
    })
    Tab:CreateButton({
      Name = "Trang sau",
      Callback = function()
        if not S.started then loadPage(1, S.query, false) return end
        if S.page >= S.total then say(L("Đang ở trang cuối.")) return end
        loadPage(S.page + 1, S.activeQuery, false)
      end,
    })

    Tab:CreateDivider({ text = "Chi tiết" })
    Tab:CreateSection("Chi tiết")
    DetailLabel = Tab:CreateLabel("Chọn một script ở trên để xem chi tiết.")
    Tab:CreateButton({
      Name = "Copy Loadstring",
      Callback = function() copyItem(selectedItem()) end,
    })
    Tab:CreateButton({
      Name = "▶ Chạy",
      Callback = function() runItem(selectedItem()) end,
    })
    Tab:CreateButton({
      Name = "Lưu vào Kho",
      Callback = function()
        local it = selectedItem()
        if not it then say(L("Chưa chọn script nào!")) return end
        if not validSlug(it.slug) then say(L("Slug không hợp lệ!")) return end
        if type(_G.HzStoreAdd) ~= "function" then say(L("❌ Kho script chưa sẵn sàng.")) return end
        local r = _G.HzStoreAdd(it.title, SB_BASE .. "/raw/" .. it.slug)
        if r == "ok" then
          say(L("💾 Đã lưu vào Kho: ") .. clean(it.title, 40))
          log("ScriptBlox: đã lưu vào Kho " .. it.slug, "SUCCESS")
        elseif r == "exists" then
          say(L("Script đã tồn tại trong danh sách."))
        elseif r == "full" then
          say(L("Danh sách đã đầy (tối đa 100)."))
        else
          say(L("Slug không hợp lệ!"))
        end
      end,
    })
    Tab:CreateLabel("Chú thích: đã xác minh · cần key · game · lượt xem")
    end) -- [V35]
  end)
  if not okSB and _G.aa3542001e064bc52 then
    pcall(_G.aa3542001e064bc52, "Tab ScriptBlox lỗi: " .. tostring(errSB), "ERROR")
  end
end

-- ===== [LƯU SCRIPTS / SAVED SCRIPTS] =====
do
  local HttpService = game:GetService("HttpService")
  local L = _G.tR9 or function(s) return s end
  local LU = HzUiS or L
  local DIR = "x8k2"
  local FILE = DIR .. "/saved_scripts.json"
  local MAX_SCRIPTS, STALE_SECONDS = ((_G.HzConst or {}).vault or {}).maxScripts or 100, ((_G.HzConst or {}).vault or {}).staleCheck or (6 * 3600) -- [V35]

  local STATUS_ICON = { OK = "✅", DEAD = "❌", ERROR = "⚠️", INVALID = "⚠️", NEW = "❔" }
  local STATUS_TEXT = {
    OK = "Hoạt động",
    DEAD = "Link chết (404)",
    ERROR = "Lỗi cú pháp",
    INVALID = "Link không hợp lệ",
    NEW = "Chưa kiểm tra",
  }

  local function validKey(k) return type(k) == "string" and #k <= 100 and k:match("^[%w_%-%.]+$") ~= nil end

  -- Nhận "loadstring(game:HttpGet("https://..."))()" hoặc link thô; lấy link trong dấu "" (và script_key nếu có)
  local function parseLoader(text)
    text = tostring(text or "")
    local key = text:match("script_key%s*=%s*[\"']([^\"']+)[\"']")
    if key and not validKey(key) then key = nil end
    local url = text:match("HttpGet%s*%(%s*[\"'](https://[^\"']+)[\"']")
      or text:match("[\"'](https://[^\"']+)[\"']")
      or text:match("(https://[^%s\"'%(%)]+)")
    if url then url = url:gsub("%s+", "") end
    return url, key
  end

  local function loaderCode(s)
    local pre = (s.key and validKey(s.key)) and ('script_key="' .. s.key .. '"\n') or ""
    return pre .. 'loadstring(game:HttpGet("' .. s.url .. '"))()'
  end

  local function log(msg, lvl) if _G.aa3542001e064bc52 then _G.aa3542001e064bc52(msg, lvl) end end
  local function say(msg) SafeNotify(L("Kho script"), msg) end
  local function fsOK() return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" end

  ----------------------------------------------------------------
  -- Kho dữ liệu
  ----------------------------------------------------------------
  local function normalize(db)
    local out = { version = 1, scripts = {}, syncUrl = "" }
    if type(db) ~= "table" then return out end
    if type(db.syncUrl) == "string" and db.syncUrl:sub(1, 8) == "https://" then out.syncUrl = db.syncUrl:sub(1, 300) end
    if type(db.scripts) ~= "table" then return out end
    local seen = {}
    for _, s in ipairs(db.scripts) do
      if type(s) == "table" and type(s.name) == "string" and type(s.url) == "string"
        and s.url:sub(1, 8) == "https://" and not seen[s.url] and #out.scripts < MAX_SCRIPTS then
        seen[s.url] = true
        table.insert(out.scripts, {
          name = s.name:sub(1, 40),
          url = s.url:sub(1, 300),
          key = validKey(s.key) and s.key or nil,
          status = STATUS_ICON[s.status] and s.status or "NEW",
          checked = tonumber(s.checked) or 0,
          added = tonumber(s.added) or os.time(),
        })
      end
    end
    return out
  end

  local Store
  do
    local ok, db = pcall(function()
      if fsOK() and isfile(FILE) then return HttpService:JSONDecode(readfile(FILE)) end
    end)
    if ok and type(db) == "table" then
      Store = normalize(db)
    else
      Store = normalize(_G.cfe70adccea5e8878)
    end
  end

  local function saveStore()
    _G.cfe70adccea5e8878 = Store -- bản dự phòng trong RAM nếu executor không có writefile
    if not fsOK() then return false end
    local ok = pcall(function()
      if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(DIR) then makefolder(DIR) end
      writefile(FILE, HttpService:JSONEncode(Store))
    end)
    return ok
  end

  ----------------------------------------------------------------
  -- Base64 (url-safe, không padding) + checksum cho mã đồng bộ
  ----------------------------------------------------------------
  local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  local REV = {}
  for i = 1, #B64 do REV[B64:sub(i, i)] = i - 1 end

  local function b64enc(data)
    local out = {}
    for i = 1, #data, 3 do
      local a, b, c = data:byte(i, i + 2)
      local v = a * 65536 + (b or 0) * 256 + (c or 0)
      local c1, c2 = math.floor(v / 262144) % 64, math.floor(v / 4096) % 64
      local c3, c4 = math.floor(v / 64) % 64, v % 64
      out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
        .. (b and B64:sub(c3 + 1, c3 + 1) or "") .. (c and B64:sub(c4 + 1, c4 + 1) or "")
    end
    return table.concat(out)
  end

  local function b64dec(s)
    local out = {}
    for i = 1, #s, 4 do
      local ch = s:sub(i, i + 3)
      local cnt, v = #ch, 0
      if cnt < 2 then return nil end
      for j = 1, 4 do
        local d = 0
        if j <= cnt then
          d = REV[ch:sub(j, j)]
          if d == nil then return nil end
        end
        v = v * 64 + d
      end
      local b1, b2, b3 = math.floor(v / 65536) % 256, math.floor(v / 256) % 256, v % 256
      if cnt == 4 then out[#out + 1] = string.char(b1, b2, b3)
      elseif cnt == 3 then out[#out + 1] = string.char(b1, b2)
      else out[#out + 1] = string.char(b1) end
    end
    return table.concat(out)
  end

  local function checksum(s)
    local a, b = 1, 0
    for i = 1, #s do
      a = (a + s:byte(i)) % 65521
      b = (b + a) % 65521
    end
    return string.format("%04x%04x", b, a)
  end

  local function exportCode()
    local list = {}
    for _, s in ipairs(Store.scripts) do table.insert(list, { n = s.name, u = s.url, k = s.key }) end
    local payload = b64enc(HttpService:JSONEncode({ v = 1, s = list }))
    return "HZ1." .. checksum(payload) .. "." .. payload
  end

  -- Trả về danh sách {name=, url=} hoặc nil nếu mã/JSON không hợp lệ
  local function parseIncoming(text)
    text = tostring(text or ""):gsub("%s+", "")
    local list = {}
    if text:sub(1, 4) == "HZ1." then
      local sum, payload = text:match("^HZ1%.(%x+)%.([%w%-_]+)$")
      if not sum or checksum(payload) ~= sum then return nil end
      local raw = b64dec(payload)
      local ok, d = pcall(function() return HttpService:JSONDecode(raw or "") end)
      if not ok or type(d) ~= "table" or type(d.s) ~= "table" then return nil end
      for _, e in ipairs(d.s) do
        if type(e) == "table" then table.insert(list, { name = e.n, url = e.u, key = e.k }) end
      end
      return list
    end
    local ok, d = pcall(function() return HttpService:JSONDecode(text) end)
    if ok and type(d) == "table" then
      local src = d.scripts or d.s
      if type(src) == "table" then
        for _, e in ipairs(src) do
          if type(e) == "table" then table.insert(list, { name = e.name or e.n, url = e.url or e.u, key = e.key or e.k }) end
        end
        return list
      end
    end
    return nil
  end

  ----------------------------------------------------------------
  -- Kiểm tra script: chỉ tải về + biên dịch thử, KHÔNG chạy
  ----------------------------------------------------------------
  local function checkUrl(url)
    if type(url) ~= "string" or url:sub(1, 8) ~= "https://" then return "INVALID" end
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if not ok or type(body) ~= "string" or body == "" then return "DEAD" end
    if body == "404: Not Found" or body == "Not Found" or body:find("404 Not Found", 1, true)
      or body:find("400: Invalid Request", 1, true) then
      return "DEAD"
    end
    if type(loadstring) ~= "function" then return "OK" end
    local fn = loadstring(body)
    if not fn then return "ERROR" end
    return "OK"
  end

  local function uniqueName(name)
    local base, n, try = name, 2, name
    local function exists(x) for _, s in ipairs(Store.scripts) do if s.name == x then return true end end return false end
    while exists(try) do
      try = base:sub(1, 34) .. " (" .. n .. ")"
      n = n + 1
    end
    return try
  end

  local function hasUrl(url) for _, s in ipairs(Store.scripts) do if s.url == url then return true end end return false end

  -- Trả về true nếu thêm được
  local function addScript(name, url, status, key)
    if type(url) ~= "string" or url:sub(1, 8) ~= "https://" or hasUrl(url) then return false end
    if #Store.scripts >= MAX_SCRIPTS then return false end
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = (url:match("([^/]+)$") or "Script"):gsub("%.lua$", ""):gsub("%.txt$", "") end
    table.insert(Store.scripts, {
      name = uniqueName(name:sub(1, 40)), url = url:sub(1, 300), key = validKey(key) and key or nil,
      status = STATUS_ICON[status] and status or "NEW",
      checked = status and os.time() or 0, added = os.time(),
    })
    return true
  end

  local function mergeIncoming(list, onStep)
    local added, skipped, n = 0, 0, #list
    if onStep then onStep(0, n) end
    for i, e in ipairs(list) do
      if addScript(e.name, e.url, nil, e.key) then added = added + 1 else skipped = skipped + 1 end
      if onStep then
        onStep(i, n)
        if i % 5 == 0 then task.wait() end
      end
    end
    if added > 0 then saveStore() end
    if onStep then onStep(n, n, true, added, skipped) end
    return added, skipped
  end

  ----------------------------------------------------------------
  -- Giao diện
  ----------------------------------------------------------------
  -- [V35] HzStoreAdd chạy được cả khi tab Kho chưa dựng UI: UI chưa có → chỉ lưu file
  -- Trả về "ok" | "exists" | "full" | "bad"
  _G.HzVaultAfterChange = nil
  _G.HzStoreAdd = function(name, url)
    if type(url) ~= "string" or url:sub(1, 8) ~= "https://" then return "bad" end
    if hasUrl(url) then return "exists" end
    if #Store.scripts >= MAX_SCRIPTS then return "full" end
    if not addScript(name, url, nil, nil) then return "bad" end
    if _G.HzVaultAfterChange then pcall(_G.HzVaultAfterChange) else saveStore() end
    return "ok"
  end

  local TabSaved = Window:CreateTab("Kho script", tonumber("11570895459"))
  _G.HzLazyTab(TabSaved, "Kho script", function() -- [V35]

  local pendingName, pendingUrl, pendingImport = "", "", ""
  local selectedLabel
  local labelToIdx, options = {}, {}
  local Dropdown, DetailLabel
  local ProgCheck, ProgImport
  local function importStep(i, n, done, a, sk)
    pcall(function()
      if done then
        ProgImport:Set(n)
        ProgImport:SetText(string.format("✅ %d  ⏭ %d", a, sk))
      elseif i == 0 then
        ProgImport:SetRange(0, math.max(1, n))
        ProgImport:SetText()
        ProgImport:Set(0)
      else
        ProgImport:Set(i)
      end
    end)
  end

  local function labelFor(s) return (STATUS_ICON[s.status] or "❔") .. " " .. s.name end

  local function buildOptions()
    labelToIdx, options = {}, {}
    for i, s in ipairs(Store.scripts) do
      local lb = labelFor(s)
      labelToIdx[lb] = i
      table.insert(options, lb)
    end
    if #options == 0 then options = { LU("— Trống —") } end
    if selectedLabel and not labelToIdx[selectedLabel] then selectedLabel = nil end
  end

  local function selectedScript()
    return selectedLabel and Store.scripts[labelToIdx[selectedLabel]] or nil
  end

  local function updateDetail()
    local s = selectedScript()
    local text
    if not s then
      text = LU("Chọn script để xem chi tiết.")
    else
      local when = (s.checked and s.checked > 0) and os.date("%Y-%m-%d %H:%M", s.checked) or LU("chưa bao giờ")
      text = LU("Trạng thái: ") .. LU(STATUS_TEXT[s.status] or STATUS_TEXT.NEW) .. "\n"
        .. LU("Mã chạy: ") .. loaderCode(s) .. "\n" .. LU("Kiểm tra: ") .. when
        .. (_G.HzAutoload.isPinned(s.url) and ("\n" .. LU("⭐ Đã ghim — tự chạy khi khởi động")) or "")
        .. ((_G.HzAutoRestore and _G.HzAutoRestore.has(s.url)) and ("\n" .. LU("Đang giữ phiên — tự chạy lại sau khi bị kick")) or "")
    end
    if DetailLabel then pcall(function() DetailLabel:Set(text) end) end
    if _G.HzVaultPinRefresh then pcall(_G.HzVaultPinRefresh) end
  end
  _G.HzVaultUpdateDetail = updateDetail
  _G.HzVaultPinRefresh = nil

  local function refreshUI()
    buildOptions()
    if Dropdown then pcall(function() Dropdown:Refresh(options, true) end) end
    updateDetail()
  end

  local function checkOne(s)
    s.status = checkUrl(s.url)
    s.checked = os.time()
  end

  local function afterChange()
    local old = selectedScript()
    saveStore()
    refreshUI()
    selectedLabel = old and labelFor(old) or nil
    updateDetail()
  end

  -- Chạy đúng dạng loadstring(game:HttpGet("..."))() sau khi kiểm tra link bên trong dấu ""
  local function runScript(s)
    local code = loaderCode(s)
    if _G.f8eefa956e6130f83 then
      local ok = pcall(function() setclipboard(code) end)
      say(ok and L("Đã copy loadstring vào clipboard!") or L("Executor không hỗ trợ copy."))
      return
    end
    if _G.HzAutoRestore then pcall(_G.HzAutoRestore.track, s.name, s.url, "vault", { key = s.key }) end
    say(L("Đang kiểm tra script..."))
    task.spawn(function()
      local status = checkUrl(s.url)
      s.status, s.checked = status, os.time()
      afterChange()
      if status == "DEAD" or status == "INVALID" then
        say(L("❌ Script này đã bị xóa bởi tác giả!"))
        log("Saved Scripts: blocked dead script " .. s.name, "WARN")
        _G.HzLogError("Link chết/không hợp lệ (" .. tostring(status) .. "): " .. tostring(s.url), "Kho script: " .. s.name)
        return
      elseif status == "ERROR" then
        say(L("❌ Script bị lỗi cú pháp, không thể chạy!"))
        _G.HzLogError("Lỗi cú pháp: " .. tostring(s.url), "Kho script: " .. s.name)
        return
      end
      if s.key then pcall(function() getgenv().script_key = s.key end) end
      local fn = loadstring(code)
      if not fn then say(L("❌ Script bị lỗi cú pháp, không thể chạy!")) return end
      local ok, err = pcall(fn)
      if ok then
        say(L("✅ Quá trình tải thành công!"))
        log("Saved Scripts: ran " .. s.name, "SUCCESS")
      else
        say(L("Lỗi thực thi: ") .. tostring(err))
        log("Saved Scripts: run error " .. s.name .. " - " .. tostring(err), "ERROR")
        _G.HzLogError(err, "Kho script: " .. s.name)
      end
    end)
  end

  buildOptions()

  TabSaved:CreateDivider({ text = "Thêm mới" })
  TabSaved:CreateSection("Thêm mới")
  TabSaved:CreateLabel("Hãy lưu script của bạn muốn lưu vào đây!")
  TabSaved:CreateInput({
    Name = "Tên",
    PlaceholderText = "VD: H",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) pendingName = tostring(t or "") end,
  })
  TabSaved:CreateInput({
    Name = "Link / loadstring",
    PlaceholderText = "loadstring(game:HttpGet(\"https://...\"))()",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) pendingUrl = tostring(t or "") end,
  })
  TabSaved:CreateButton({
    Name = "Lưu & kiểm tra",
    Callback = function()
      if pendingUrl:gsub("%s+", "") == "" then say(L("Vui lòng nhập link script trước!")) return end
      local url, key = parseLoader(pendingUrl)
      if not url then say(L("Không thấy link https trong nội dung!")) return end
      if hasUrl(url) then say(L("Script đã tồn tại trong danh sách.")) return end
      if #Store.scripts >= MAX_SCRIPTS then say(L("Danh sách đã đầy (tối đa 100).")) return end
      say(L("Đã nhận diện link: ") .. url)
      task.spawn(function()
        local status = checkUrl(url)
        if status == "DEAD" or status == "INVALID" then
          say(L("Không thể lưu: script đã chết (404/không tải được)."))
          log("Saved Scripts: refused dead/invalid link " .. url, "WARN")
          return
        end
        if addScript(pendingName, url, status, key) then
          local ok = saveStore()
          local s = Store.scripts[#Store.scripts]
          selectedLabel = labelFor(s)
          refreshUI()
          selectedLabel = labelFor(s)
          updateDetail()
          if status == "ERROR" then
            say(L("Đã lưu nhưng script bị lỗi cú pháp — hãy cân nhắc trước khi chạy."))
          else
            say(L("Đã lưu: ") .. s.name)
          end
          if not ok then say(L("Không thể ghi file — dữ liệu chỉ lưu tạm trong phiên này.")) end
        end
      end)
    end,
  })

  TabSaved:CreateDivider({ text = "Danh sách" })
  TabSaved:CreateSection("Danh sách")
  Dropdown = TabSaved:CreateDropdown({
    Name = "Chọn script",
    Options = options,
    CurrentOption = { options[1] },
    MultipleOptions = false,
    Callback = function(sel)
      local v = sel and sel[1]
      selectedLabel = (v and labelToIdx[v]) and v or nil
      updateDetail()
    end,
  })
  DetailLabel = TabSaved:CreateLabel("Chọn script để xem chi tiết.")

  TabSaved:CreateButton({
    Name = "▶ Chạy",
    Callback = function()
      local s = selectedScript()
      if not s then say(L("Chưa chọn script nào!")) return end
      runScript(s)
    end,
  })
  -- và bấm lần nữa sẽ tắt (_G.HzAutoload.remove). Danh sách lưu ở x8k2/autoload.json (chỉ tên + link). Bật/tắt toàn bộ ở Cài đặt → Tự động chạy.
  _G.HzVaultPinState = "off"
  _G.HzVaultPinBtn = TabSaved:CreateButton({
    Name = "Tự động chạy",
    Callback = function()
      if _G.HzBtnSetting then return end -- handle:Set (đổi chữ nút) vô tình gọi callback thì bỏ qua
      local s = selectedScript()
      if not s then say(L("Chưa chọn script nào!")) return end
      if _G.HzAutoload.isPinned(s.url) then
        _G.HzAutoload.remove(s.url)
        say(L("☄️ Đã tắt Auto-run: ") .. s.name)
      else
        local r = _G.HzAutoload.toggle(s.name, s.url)
        if r == "pinned" then
          say(L("☄️ Đã bật Auto-run: ") .. s.name)
        elseif r == "full" then
          say(L("Danh sách ghim đã đầy (tối đa 20)."))
        else
          say(L("Link không hợp lệ."))
        end
      end
      updateDetail()
    end,
  })
  _G.HzVaultPinRefresh = function()
    local s = selectedScript()
    local state = (s and _G.HzAutoload.isPinned(s.url)) and "on" or "off"
    if _G.HzVaultPinState == state then return end
    local keyOn, keyOff = "Đã bật (bấm để tắt)", "Tự động chạy"
    local oldKey = (_G.HzVaultPinState == "on") and keyOn or keyOff
    local newKey = (state == "on") and keyOn or keyOff
    _G.HzVaultPinState = state
    _G.HzSetBtnText(_G.HzVaultPinBtn, LU(newKey), LU(oldKey))
  end
  TabSaved:CreateButton({
    Name = "Kiểm tra",
    Callback = function()
      local s = selectedScript()
      if not s then say(L("Chưa chọn script nào!")) return end
      say(L("Đang kiểm tra script..."))
      task.spawn(function()
        local oldLabel = labelFor(s)
        checkOne(s)
        saveStore()
        if selectedLabel == oldLabel then selectedLabel = labelFor(s) end
        local keep = selectedLabel
        refreshUI()
        selectedLabel = keep
        updateDetail()
        say(labelFor(s) .. " — " .. L(STATUS_TEXT[s.status]))
      end)
    end,
  })
  TabSaved:CreateButton({
    Name = "Kiểm tra hết",
    Callback = function()
      if #Store.scripts == 0 then say(L("Danh sách trống.")) return end
      say(L("Đang kiểm tra tất cả script..."))
      task.spawn(function()
        local oldSel = selectedScript()
        local okN, badN, total = 0, 0, #Store.scripts
        pcall(function() ProgCheck:SetRange(0, math.max(1, total)) ProgCheck:SetText() ProgCheck:Set(0) end)
        for i, s in ipairs(Store.scripts) do
          checkOne(s)
          if s.status == "OK" then okN = okN + 1 else badN = badN + 1 end
          pcall(function() ProgCheck:Set(i) end)
          task.wait(0.25)
        end
        pcall(function() ProgCheck:SetText(string.format("✅ %d  ❌ %d", okN, badN)) end)
        saveStore()
        refreshUI()
        selectedLabel = oldSel and labelFor(oldSel) or nil
        updateDetail()
        say(string.format(L("Đã kiểm tra %d script: %d hoạt động, %d lỗi."), #Store.scripts, okN, badN))
      end)
    end,
  })
  ProgCheck = TabSaved:CreateProgress({ name = "Tiến trình kiểm tra", range = { 0, math.max(1, #Store.scripts) }, value = 0, format = HzFmtN })
  TabSaved:CreateButton({
    Name = "Copy loadstring",
    Callback = function()
      local s = selectedScript()
      if not s then say(L("Chưa chọn script nào!")) return end
      local ok = pcall(function() setclipboard(loaderCode(s)) end)
      say(ok and L("Đã copy loadstring vào clipboard!") or L("Executor không hỗ trợ copy."))
    end,
  })
  TabSaved:CreateButton({
    Name = "Xoá",
    Callback = function()
      local s = selectedScript()
      if not s then say(L("Chưa chọn script nào!")) return end
      local idx = labelToIdx[selectedLabel]
      _G.HzConfirm("Xoá script?", "Xoá “" .. tostring(s.name) .. "” khỏi Kho script (và bỏ ghim Auto-run nếu có).", "Xoá", function()
        if Store.scripts[idx] ~= s then return end -- danh sách đã đổi lúc popup đang mở
        table.remove(Store.scripts, idx)
        saveStore()
        pcall(function() _G.HzAutoload.remove(s.url) end)
        local name = s.name
        selectedLabel = nil
        refreshUI()
        say(L("Đã xóa: ") .. name)
      end)
    end,
  })

  TabSaved:CreateDivider({ text = "Đồng bộ" })
  TabSaved:CreateSection("Đồng bộ")
  TabSaved:CreateLabel("Danh sách lưu ở x8k2/saved_scripts.json. Sang máy khác: xuất mã rồi nhập lại. Chỉ nhập từ nguồn tin cậy.")
  TabSaved:CreateButton({
    Name = "Xuất mã",
    Callback = function()
      if #Store.scripts == 0 then say(L("Danh sách trống.")) return end
      local code = exportCode()
      local ok = pcall(function() setclipboard(code) end)
      pcall(function()
        if fsOK() then writefile(DIR .. "/sync_code.txt", code) end
      end)
      if ok then
        say(string.format(L("Đã xuất mã đồng bộ (%d script) và copy vào clipboard."), #Store.scripts))
      else
        print("[x8K2] sync code: " .. code)
        say(L("Executor không hỗ trợ copy — mã đã được in ra console (F9)."))
      end
    end,
  })
  TabSaved:CreateInput({
    Name = "Mã hoặc link",
    PlaceholderText = "HZ1.… / https://…",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) pendingImport = tostring(t or "") end,
  })
  TabSaved:CreateButton({
    Name = "Nhập mã",
    Callback = function()
      local text = pendingImport:gsub("%s+", "")
      if text == "" then say(L("Mã đồng bộ không hợp lệ hoặc bị lỗi.")) return end
      task.spawn(function()
        if text:sub(1, 8) == "https://" then
          local ok, body = pcall(function() return game:HttpGet(text, true) end)
          if not ok or type(body) ~= "string" or body == "" then
            say(L("Không tải được nội dung từ link."))
            return
          end
          text = body
        end
        local list = parseIncoming(text)
        if not list then say(L("Mã đồng bộ không hợp lệ hoặc bị lỗi.")) return end
        local added, skipped = mergeIncoming(list, importStep)
        refreshUI()
        say(string.format(L("Đã nhập %d script mới (bỏ qua %d trùng)."), added, skipped))
      end)
    end,
  })
  ProgImport = TabSaved:CreateProgress({ name = "Tiến trình nhập", range = { 0, 1 }, value = 0, text = "—", format = HzFmtN })
  TabSaved:CreateInput({
    Name = "Link tự đồng bộ",
    PlaceholderText = "https://gist.githubusercontent.com/...",
    RemoveTextAfterFocusLost = false,
    Callback = function(t)
      t = tostring(t or ""):gsub("%s+", "")
      if t == (Store.syncUrl or "") then return end
      if t == "" or t:sub(1, 8) == "https://" then
        Store.syncUrl = t
        saveStore()
        say(L("Đã lưu link tự động đồng bộ."))
      end
    end,
  })
  TabSaved:CreateLabel("Mỗi lần mở menu sẽ nhập thêm từ link này.")

  -- Tự đồng bộ từ link + tự kiểm tra script cũ khi mở menu
  task.spawn(function()
    task.wait(3)
    if Store.syncUrl and Store.syncUrl ~= "" then
      local ok, body = pcall(function() return game:HttpGet(Store.syncUrl, true) end)
      if ok and type(body) == "string" and body ~= "" then
        local list = parseIncoming(body)
        if list then
          local added = mergeIncoming(list, importStep)
          if added > 0 then
            refreshUI()
            say(string.format(L("Đã nhập %d script mới (bỏ qua %d trùng)."), added, 0))
          end
        end
      end
    end
    local now, n, changed = os.time(), 0, false
    for _, s in ipairs(Store.scripts) do
      if n >= 30 then break end
      if now - (s.checked or 0) > STALE_SECONDS then
        checkOne(s)
        changed = true
        n = n + 1
        task.wait(0.4)
      end
    end
    if changed then
      local oldSel = selectedScript()
      saveStore()
      refreshUI()
      selectedLabel = oldSel and labelFor(oldSel) or nil
      updateDetail()
    end
  end)
  _G.HzVaultAfterChange = afterChange -- [V35]
  end) -- [V35] hết HzLazyTab Kho
end

-- [TAB ÂM NHẠC - PROMAX EDITION (UPGRADED TO LIST VIEW)]
local TabMusic = Window:CreateTab("Nhạc", tonumber("14420842855"))

local MusicHUDGui = Instance.new("ScreenGui")
MusicHUDGui.Name = HzN.musichud
MusicHUDGui.IgnoreGuiInset = true
MusicHUDGui.ResetOnSpawn = false -- [FIX] Chống mất UI khi chết
MusicHUDGui.Enabled = false
pcall(function()
  MusicHUDGui.Parent = game:GetService("CoreGui")
end)
if not MusicHUDGui.Parent then
  MusicHUDGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local MusicHUDFrame = Instance.new("Frame")
MusicHUDFrame.Size = UDim2.new(0, 190, 0, 30)
MusicHUDFrame.AnchorPoint = Vector2.new(0.5, 0)
MusicHUDFrame.Position = UDim2.new(0.5, 0, 0, 15)
MusicHUDFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MusicHUDFrame.BackgroundTransparency = 0.25
MusicHUDFrame.BorderSizePixel = 0
MusicHUDFrame.Parent = MusicHUDGui

local HUDCorner = Instance.new("UICorner")
HUDCorner.CornerRadius = UDim.new(0, 8)
HUDCorner.Parent = MusicHUDFrame

local HUDGradient = Instance.new("UIGradient")
HUDGradient.Color = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180))
})
HUDGradient.Rotation = 45
HUDGradient.Parent = MusicHUDFrame

local HUDStroke = Instance.new("UIStroke")
HUDStroke.Color = Color3.fromRGB(0, 255, 255)
HUDStroke.Thickness = 2
HUDStroke.Transparency = 0.1
HUDStroke.Parent = MusicHUDFrame

if _G.HzLiquidGlass then
  _G.HzLiquidGlass(MusicHUDFrame, { radius = 16, transparency = 0.5, keepStrokeColor = true, strokeThickness = 1.5 })
end

_G.HzViz = nil
if _G.HzPerfLvl ~= "low" and not _G.HzLiteLoad and _G.HzGlassUI ~= false then -- [PERF] LOW: bỏ hẳn visualizer
  pcall(function()
    local N = (_G.HzPerfLvl == "med") and 8 or 12 -- [PERF] HIGH 12 thanh | MED 8 thanh
    local holder = Instance.new("Frame")
    holder.Name = "Viz"
    holder.BackgroundTransparency = 1
    holder.Active = false
    holder.ZIndex = 0
    holder.Size = UDim2.new(1, -16, 1, -8)
    holder.Position = UDim2.new(0, 8, 0, 4)
    holder.Parent = MusicHUDFrame
    local bars, lv, spd, pha = {}, {}, {}, {}
    for i = 1, N do
      local b = Instance.new("Frame")
      b.Name = "Bar" .. i
      b.AnchorPoint = Vector2.new(0, 1)
      b.Size = UDim2.new(1 / N, -3, 0.06, 0)
      b.Position = UDim2.new((i - 1) / N, 1, 1, 0)
      b.BackgroundColor3 = Color3.fromHSV(0.5 + 0.22 * (i - 1) / (N - 1), 0.7, 1) -- cyan -> tím
      b.BackgroundTransparency = 0.5
      b.BorderSizePixel = 0
      b.Active = false
      b.ZIndex = 0
      local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = b
      b.Parent = holder
      bars[i], lv[i], spd[i], pha[i] = b, 0.06, 3 + (i % 4) * 0.9, i * 0.9
    end
    _G.HzViz = function(t, playing)
      local loud = 0
      if playing and CurrentMusic then
        local ok, v = pcall(function() return CurrentMusic.PlaybackLoudness end)
        if ok and type(v) == "number" then loud = v end
      end
      local n = math.clamp((loud / 450) ^ 0.7, 0, 1) -- nén: nhạc nhỏ vẫn thấy chuyển động
      for i = 1, N do
        local target = 0.06
        if playing then target = 0.06 + n * (0.55 + 0.45 * math.sin(t * spd[i] + pha[i])) * 0.94 end
        lv[i] = lv[i] + (target - lv[i]) * (target > lv[i] and 0.6 or 0.25) -- lên nhanh, xuống êm
        bars[i].Size = UDim2.new(1 / N, -3, math.clamp(lv[i], 0.06, 1), 0)
      end
    end
  end)
end

local MusicIcon = Instance.new("ImageLabel")
MusicIcon.Size = UDim2.new(0, 18, 0, 18)
MusicIcon.Position = UDim2.new(0, 8, 0.5, -9)
MusicIcon.BackgroundTransparency = 1
MusicIcon.Image = "rbxassetid://113504329593037"
MusicIcon.Parent = MusicHUDFrame

local MusicHUDLabel = Instance.new("TextLabel")
MusicHUDLabel.Size = UDim2.new(1, -34, 1, 0)
MusicHUDLabel.Position = UDim2.new(0, 30, 0, 0)
MusicHUDLabel.BackgroundTransparency = 1
MusicHUDLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
MusicHUDLabel.TextXAlignment = Enum.TextXAlignment.Left
MusicHUDLabel.Font = Enum.Font.GothamBold
MusicHUDLabel.TextSize = 12
MusicHUDLabel.Text = _G.tR9("Không Có")
MusicHUDLabel.TextWrapped = true
MusicHUDLabel.Parent = MusicHUDFrame

local IsLooped = true
local CurrentSelectedSongName = ""
if _G.HzMusicRuntime then
  IsLooped = _G.HzMusicRuntime.looped ~= false
  CurrentVolume = tonumber(_G.HzMusicRuntime.volume) or CurrentVolume
  CurrentSelectedSongName = tostring(_G.HzMusicRuntime.name or "")
end

TabMusic:CreateDivider({ text = "Trình phát" })
TabMusic:CreateSection("Trình phát")

TabMusic:CreateSlider({
  Name = "Âm lượng",
  Range = {0, 10},
  Increment = 0.5,
  CurrentValue = CurrentVolume,
  Callback = function(Value)
    CurrentVolume = Value
    if CurrentMusic then
      CurrentMusic.Volume = Value
    end
  end,
})

TabMusic:CreateToggle({
  Name = "HUD nhạc",
  CurrentValue = false,
  Callback = function(Value)
    if MusicHUDGui then
      MusicHUDGui.Enabled = Value
    end
  end,
})

local LoopToggle = TabMusic:CreateToggle({
  Name = "Lặp bài này",
  CurrentValue = IsLooped,
  Callback = function(Value)
    IsLooped = Value
    if CurrentMusic then
      CurrentMusic.Looped = IsLooped
    end
    if IsLooped then
      Notify("Music", "Đã bật lặp bài!")
    else
      Notify("Music", "Đã tắt lặp bài.")
    end
  end,
})

TabMusic:CreateButton({
  Name = "Dừng nhạc",
  Callback = function()
    if CurrentMusic then
      CurrentMusic:Stop()
      CurrentMusic:Destroy()
      CurrentMusic = nil
      CurrentSelectedSongName = ""
      _G.HzMusicRuntime = nil
      Notify("Music", "Đã dừng nhạc!")
    else
      Notify("Music", "Chưa có nhạc đang phát.")
    end
  end
})

TabMusic:CreateDivider({ text = "Thư viện" })
TabMusic:CreateSection("Thư viện")

local MusicDatabase = {
  ["Ai đưa em về"] = "119589720384457",
  ["F-L-Y"] = "76819270320985",
  ["NO MERCI"] = "136843754633280",
  ["Stay With Me (Remix)"] = "137717310854691",
  ["CALIENTE (Mega Slowed)"] = "105492220688862",
  ["Chill + Fonk"] = "82149511707056",
  ["Fonk"] = "108630241662018",
  ["SAIKAI"] = "79262785467239",
  ["Đồi Gió Sao Quá Khó Để Gặp Em"] = "83705430066881",
  ["Nocturne in E-Flat Major"] = "9045765634",
  ["Nhạc Buồn"] = "83705430066881",
  ["CHRISTMAS FUNK"] = "140614684910646",
  ["Mad Phonk Addict"] = "140274552295461",
  ["Low Cortisol"] = "110919391228823",
  ["Infinitely Expanding"] = "131649240815291",
  ["Stray"] = "120102995443063",
  ["Treachery (Bleach)"] = "138545624185373",
  ["Forgotten Past"] = "1838873271",
  ["underfell sans theme"] = "101730223568557",
  ["Thunderclap"] = "103590461924679",
  ["I'm a Believer - Instrumental"] = "9039704032",
  ["d3r - love domb"] = "18841891575",
  ["CUTEMAKMAKFUNK (Slowed)"] = "120871403922972",
  ["CoolBeat"] = "110788401793874",
  ["Rainie love"] = "79277371759525",
  ["Black Heart"] = "126517719517563",
  ["Rồng Thiên"] = "86406401105714",
  ["Tự Đa Tình"] = "102740989485567",
  ["Hachimi"] = "88349464000927",
  ["Nhạc Trung"] = "82475562998551",
  ["Kerosense"] = "17647322226",
  ["MONTAGEM - PRRUTCHAKO"] = "9045765634",
  ["Want To Love"] = "104846670980072",
  ["Madira"] = "8494188412",
  ["Phonk Remix"] = "16662833837",
  ["Phonk-2"] = "16190783774",
  ["Em là gió"] = "138802194906464",
  ["Morning"] = "140722099430139",
  ["Dịu dàng"] = "140695633562281",
  ["Phonk(Super slowed)"] = "127521546166507",
  ["Deadlines"] = "140628387917926",
  ["Lời hứa sóng cuốn"] = "134473054863425",
  ["Chạm Lặng"] = "106534572994709",
  ["Nothin On Me"] = "9048375035",
  ["Lofi VietNam Christmas"] = "129361584564255",
  ["Nắng Nhạt Dần"] = "128310680553165",
  ["Mộng Hoa Bay"] = "121439292363731",
  ["Tấm Gương Ký Ức"] = "114337890778326",
  ["Đêm Cuối Cùng"] = "110842976047767",
  ["Trái Tim Lạc Lối"] = "86048865916358",
  ["Dưới Ánh Đèn Đêm"] = "139254533597672",
  ["Mơ Một Lần"] = "77538934822932",
  ["Funk Espia (Slowed)"] = "93722279965317",
  ["Fusion (Slowed)"] = "92500405029901",
  ["Fusion (Original)"] = "89180400948567",
  ["Funk Espia (Speed Up)"] = "87186168756872",
  ["Next!(Speed Up)"] = "105630261430700",
  ["Tiktok"] = "118507373399694",
  ["Guru"] = "125598466208798",
  ["Moment After The Fall"] = "117533978765066",
  ["Next!(Original Mix)"] = "89576775902250",
  ["Itsy Bitsy Spider (Super Slowed)"] = "85491269651694",
  ["StarDust (Short)"] = "123289189590617",
  ["Resistance Treinamento (Super Sped Up)"] = "90920762460306",
  ["StarDust (Speed up)"] = "123289189590617",
  ["X-Knight (SpeedUp+)"] = "81055807452410",
  ["Xeno"] = "127502623565534",
  ["Fisson (Speed Up)"] = "134011921316879",
  ["Fisson (Original)"] = "118349786848415",
  ["StarDust"] = "90359988371949",
  ["Dare"] = "139188421510869",
  ["I Hope"] = "129928491449088",
  ["Vậy là anh sai"] = "129772438082327",
  ["La la ta có em"] = "102882490871540",
  ["Mưa đỏ"] = "102055738614721",
  ["Loyal"] = "132480292381760",
  ["Quốc ca"] = "1845922899",
  ["Không một lời từ biệt "] = "126245988087988",
  ["Tuổi trẻ thế hệ bác hồ"] = "113815049685028",
  ["Thăng hoa dưới ánh sao"] = "81163148407120",
  ["Khô gà"] = "99152674992699",
}

local FullSongList = {}
for name, _ in pairs(MusicDatabase) do
  table.insert(FullSongList, name)
end
table.sort(FullSongList)

local PlaylistDropdown = TabMusic:CreateDropdown({
  Name = "Chọn bài",
  Options = { "Chọn bài hát..." },
  CurrentOption = {"Chọn bài hát..."},
  MultipleOptions = false,
  Save = false,
  Callback = function(Options)
    if Options[1] == "Chọn bài hát..." then return end
    CurrentSelectedSongName = Options[1]
    if CurrentSelectedSongName and MusicDatabase[CurrentSelectedSongName] then
      PlayMusic(MusicDatabase[CurrentSelectedSongName], CurrentSelectedSongName)
    end
  end,
})

_G.HzPlaylistFilled = false
_G.HzFillPlaylist = function()
  if _G.HzPlaylistFilled then return end
  _G.HzPlaylistFilled = true
  pcall(function() PlaylistDropdown:Refresh(FullSongList, true) end)
end
_G.HzLazyTab(TabMusic, "Nhạc", function() _G.HzFillPlaylist() end) -- [V35] nạp playlist khi mở tab Nhạc
task.delay(3, function() pcall(_G.HzFillPlaylist) end) -- dự phòng: nạp sau 3s

TabMusic:CreateInput({
  Name = "Lọc bài hát",
  PlaceholderText = "Gõ để tìm...",
  RemoveTextAfterFocusLost = false,
  Callback = function(Text)
    _G.HzPlaylistFilled = true
    local FilteredList = {}
    if Text == "" then
      PlaylistDropdown:Refresh(FullSongList, true)
      return
    end

    local lowerText = string.lower(Text)
    for name, _ in pairs(MusicDatabase) do
      if string.find(string.lower(name), lowerText) then
        table.insert(FilteredList, name)
      end
    end

    if #FilteredList > 0 then
      table.sort(FilteredList)
      PlaylistDropdown:Refresh(FilteredList, true)
    else
      PlaylistDropdown:Refresh({"❌ Không có kết quả"}, true)
    end
  end,
})

TabMusic:CreateSection("Phát theo ID")
local CustomID = ""
TabMusic:CreateInput({
  Name = "Sound ID",
  PlaceholderText = "Ví dụ: 127521546166507",
  RemoveTextAfterFocusLost = false,
  Callback = function(Text)
    CustomID = tostring(Text or ""):match("%d+") or ""
  end,
})

TabMusic:CreateButton({
  Name = "▶ Phát ID",
  Callback = function()
    if CustomID == "" then
      Notify("Lỗi", "Nhập ID nhạc trước!")
      return
    end
    task.spawn(function()
      local testSound = Instance.new("Sound")
      testSound.SoundId = "rbxassetid://" .. CustomID
      testSound.Volume = 0
      testSound.Parent = game:GetService("SoundService")

      local loaded = false
      local timeout = false

      local loadConn = testSound.Loaded:Connect(function()
        loaded = true
        testSound:Destroy()
        if not timeout then
          CurrentSelectedSongName = "ID: " .. CustomID
          PlayMusic(CustomID, "Custom Sound ("..CustomID..")")
        end
      end)

      task.delay(5, function()
        if not loaded then
          timeout = true
          loadConn:Disconnect()
          testSound:Destroy()
          Notify("Lỗi", "ID nhạc không dùng được.")
        end
      end)
      testSound:Play()
    end)
  end
})

-- ===== [MUSIC HUB PRO] điều khiển phát, hẹn giờ, tốc độ + HUD tương tác =====
local MusicL = HzUiS or _G.tR9 or function(x) return x end
local MusicHistory = {}
local ShuffleOn = true
if _G.HzMusicRuntime then ShuffleOn = _G.HzMusicRuntime.shuffle ~= false end
local CurrentSpeed = 1
local SleepToken = 0
local ShuffleToggle

local function fmtTime(t)
  t = math.max(0, math.floor(tonumber(t) or 0))
  return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

local function StopMusic()
  if CurrentMusic then
    pcall(function() CurrentMusic:Stop() CurrentMusic:Destroy() end)
    CurrentMusic = nil
    CurrentSelectedSongName = ""
    _G.HzMusicRuntime = nil
    return true
  end
  return false
end

local function PlayNextSong(dir)
  dir = dir or 1
  local list = FullSongList
  if #list == 0 then return end
  if dir > 0 and CurrentSelectedSongName ~= "" then
    table.insert(MusicHistory, CurrentSelectedSongName)
    if #MusicHistory > 50 then table.remove(MusicHistory, 1) end
  end
  local name
  if ShuffleOn then
    name = list[math.random(1, #list)]
    local tries = 0
    while name == CurrentSelectedSongName and #list > 1 and tries < 10 do
      name = list[math.random(1, #list)]
      tries = tries + 1
    end
  else
    local idx = table.find(list, CurrentSelectedSongName)
    idx = idx and (((idx - 1 + dir) % #list) + 1) or 1
    name = list[idx]
  end
  if name and MusicDatabase[name] then
    CurrentSelectedSongName = name
    PlayMusic(MusicDatabase[name], name)
  end
end

local function PrevSong()
  local prev = table.remove(MusicHistory)
  if prev and MusicDatabase[prev] then
    CurrentSelectedSongName = prev
    PlayMusic(MusicDatabase[prev], prev)
  else
    PlayNextSong(-1)
  end
end

local function TogglePause()
  if not CurrentMusic then Notify("Music", "Chưa có nhạc đang phát.") return end
  if CurrentMusic.IsPlaying then CurrentMusic:Pause() else CurrentMusic:Resume() end
end
_G.HzToggleMusic = TogglePause

-- trước khi dọn Sound. Đọc trực tiếp CurrentMusic/IsLooped/ShuffleOn nên không cần cập nhật rải rác ở từng callback.
_G.HzMusicSnap = function()
  local r, m = _G.HzMusicRuntime, CurrentMusic
  if type(r) ~= "table" or not m or not m.Parent then return end
  r.timePos, r.paused = m.TimePosition, m.IsPaused == true
  r.volume, r.looped, r.shuffle = CurrentVolume, IsLooped, ShuffleOn
  if CurrentSelectedSongName ~= "" then r.name = CurrentSelectedSongName end
end

local function SeekBy(sec)
  if CurrentMusic and CurrentMusic.TimeLength > 0 then
    CurrentMusic.TimePosition = math.clamp(CurrentMusic.TimePosition + sec, 0, math.max(0, CurrentMusic.TimeLength - 0.5))
  end
end

local function SetLoop(v)
  IsLooped = v
  if CurrentMusic then CurrentMusic.Looped = v end
  pcall(function() LoopToggle:Set(v) end)
end

local function SetShuffle(v)
  ShuffleOn = v
  pcall(function() ShuffleToggle:Set(v) end)
end

----------------------------------------------------------------
-- Tab: Điều khiển phát nhạc
----------------------------------------------------------------
TabMusic:CreateDivider({ text = "Điều khiển" })
TabMusic:CreateSection("Điều khiển")
local NowLabel = TabMusic:CreateLabel("🎧 Chưa phát gì")

TabMusic:CreateButton({ Name = "Trước", Callback = PrevSong })
TabMusic:CreateButton({ Name = "Phát/Tạm dừng", Callback = TogglePause })
TabMusic:CreateButton({ Name = "Tiếp", Callback = function() PlayNextSong(1) end })
TabMusic:CreateButton({ Name = "Lùi 10s", Callback = function() SeekBy(-10) end })
TabMusic:CreateButton({ Name = "Tới 10s", Callback = function() SeekBy(10) end })
TabMusic:CreateButton({ Name = "Ngẫu nhiên", Callback = function()
  local old = ShuffleOn
  ShuffleOn = true
  PlayNextSong(1)
  ShuffleOn = old
end })

TabMusic:CreateSlider({
  Name = "Tốc độ",
  Range = {0.5, 2},
  Increment = 0.05,
  CurrentValue = 1,
  Callback = function(v)
    CurrentSpeed = v
    if CurrentMusic then pcall(function() CurrentMusic.PlaybackSpeed = v end) end
  end,
})
ShuffleToggle = TabMusic:CreateToggle({
  Name = "Trộn bài",
  CurrentValue = ShuffleOn,
  Callback = function(v) ShuffleOn = v end,
})
TabMusic:CreateSlider({
  Name = "Hẹn giờ (phút)",
  Range = {0, 120},
  Increment = 5,
  CurrentValue = 0,
  Callback = function(v)
    SleepToken = SleepToken + 1
    local tok = SleepToken
    local gen = _G.HzMusicGen
    if v > 0 then
      Notify("Music", string.format(MusicL("Nhạc tắt sau %d phút."), v))
      task.delay(v * 60, function()
        if tok == SleepToken and gen == _G.HzMusicGen and StopMusic() then Notify("Music", "Đã dừng nhạc!") end
      end)
    end
  end,
})

----------------------------------------------------------------
-- HUD Âm Nhạc tương tác: kéo thả, thanh tiến trình bấm để tua, nút điều khiển, thu gọn
----------------------------------------------------------------
do
  local UIS = game:GetService("UserInputService")
  local HUD_W, H_COLLAPSED, H_EXPANDED = 264, 30, 90
  local ON_COLOR, OFF_COLOR = Color3.fromRGB(0, 150, 170), Color3.fromRGB(38, 38, 44)
  local expanded = true

  MusicHUDFrame.Size = UDim2.new(0, HUD_W, 0, H_EXPANDED)
  MusicHUDFrame.Active = true

  -- Giữ HUD luôn nằm trong màn hình (không kéo ra ngoài mất luôn được)
  local function clampHud()
    if not MusicHUDFrame.Parent then return end
    local vp = MusicHUDGui.AbsoluteSize
    local pw, ph = vp.X, vp.Y
    if pw <= 0 or ph <= 0 then return end
    local pos, size, ap = MusicHUDFrame.Position, MusicHUDFrame.Size, MusicHUDFrame.AnchorPoint
    local w = size.X.Scale * pw + size.X.Offset
    local h = size.Y.Scale * ph + size.Y.Offset
    local ax = pos.X.Scale * pw + pos.X.Offset
    local ay = pos.Y.Scale * ph + pos.Y.Offset
    local left = math.clamp(ax - ap.X * w, 0, math.max(0, pw - w))
    local top = math.clamp(ay - ap.Y * h, 0, math.max(0, ph - h))
    MusicHUDFrame.Position = UDim2.new(
      pos.X.Scale, left + ap.X * w - pos.X.Scale * pw,
      pos.Y.Scale, top + ap.Y * h - pos.Y.Scale * ph
    )
  end
  MusicHUDGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(clampHud)
  task.defer(clampHud)
  MusicHUDLabel.Size = UDim2.new(1, -62, 0, 30)
  MusicHUDLabel.TextWrapped = false
  MusicHUDLabel.TextTruncate = Enum.TextTruncate.AtEnd

  local function newBtn(parent, text, size)
    local b = Instance.new("TextButton")
    b.Size = size
    b.BackgroundColor3 = OFF_COLOR
    b.BackgroundTransparency = 0.1
    b.AutoButtonColor = true
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.BorderSizePixel = 0
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b
    b.Parent = parent
    return b
  end

  local function newText(parent, pos, size, align)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position, l.Size = pos, size
    l.Font = Enum.Font.Gotham
    l.TextSize = 10
    l.TextColor3 = Color3.fromRGB(215, 215, 215)
    l.TextXAlignment = align
    l.Text = "0:00"
    l.Parent = parent
    return l
  end

  -- Nút thu gọn / mở rộng
  local CollapseBtn = newBtn(MusicHUDFrame, "▴", UDim2.new(0, 22, 0, 22))
  CollapseBtn.Position = UDim2.new(1, -28, 0, 4)
  CollapseBtn.TextSize = 12

  -- Thanh tiến trình (bấm hoặc kéo để tua)
  local SeekBtn = Instance.new("TextButton")
  SeekBtn.BackgroundTransparency = 1
  SeekBtn.Text = ""
  SeekBtn.AutoButtonColor = false
  SeekBtn.Position = UDim2.new(0, 8, 0, 33)
  SeekBtn.Size = UDim2.new(1, -16, 0, 14)
  SeekBtn.Parent = MusicHUDFrame

  local BarBG = Instance.new("Frame")
  BarBG.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
  BarBG.BorderSizePixel = 0
  BarBG.Position = UDim2.new(0, 0, 0.5, -2)
  BarBG.Size = UDim2.new(1, 0, 0, 4)
  BarBG.Parent = SeekBtn
  local bgc = Instance.new("UICorner") bgc.CornerRadius = UDim.new(1, 0) bgc.Parent = BarBG

  local BarFill = Instance.new("Frame")
  BarFill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
  BarFill.BorderSizePixel = 0
  BarFill.Size = UDim2.new(0, 0, 1, 0)
  BarFill.Parent = BarBG
  local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = BarFill

  local TimeLeft = newText(MusicHUDFrame, UDim2.new(0, 8, 0, 47), UDim2.new(0, 100, 0, 12), Enum.TextXAlignment.Left)
  local TimeRight = newText(MusicHUDFrame, UDim2.new(1, -108, 0, 47), UDim2.new(0, 100, 0, 12), Enum.TextXAlignment.Right)

  -- Hàng nút điều khiển
  local Row = Instance.new("Frame")
  Row.BackgroundTransparency = 1
  Row.Position = UDim2.new(0, 8, 0, 62)
  Row.Size = UDim2.new(1, -16, 0, 24)
  Row.Parent = MusicHUDFrame
  local lay = Instance.new("UIListLayout")
  lay.FillDirection = Enum.FillDirection.Horizontal
  lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
  lay.VerticalAlignment = Enum.VerticalAlignment.Center
  lay.Padding = UDim.new(0, 3)
  lay.Parent = Row

  local BSIZE = UDim2.new(0, 28, 0, 24)
  local BtnPrev = newBtn(Row, "⏮", BSIZE)
  local BtnBack = newBtn(Row, "⏪", BSIZE)
  local BtnPlay = newBtn(Row, "▶", BSIZE)
  local BtnFwd = newBtn(Row, "⏩", BSIZE)
  local BtnNext = newBtn(Row, "⏭", BSIZE)
  local BtnLoop = newBtn(Row, "🔁", BSIZE)
  local BtnShuf = newBtn(Row, "🔀", BSIZE)
  local BtnStop = newBtn(Row, "⏹", BSIZE)

  BtnPrev.Activated:Connect(PrevSong)
  BtnBack.Activated:Connect(function() SeekBy(-10) end)
  BtnPlay.Activated:Connect(TogglePause)
  BtnFwd.Activated:Connect(function() SeekBy(10) end)
  BtnNext.Activated:Connect(function() PlayNextSong(1) end)
  BtnLoop.Activated:Connect(function() SetLoop(not IsLooped) end)
  BtnShuf.Activated:Connect(function() SetShuffle(not ShuffleOn) end)
  BtnStop.Activated:Connect(function()
    if StopMusic() then Notify("Music", "Đã dừng nhạc!") end
  end)

  CollapseBtn.Activated:Connect(function()
    expanded = not expanded
    MusicHUDFrame.Size = UDim2.new(0, HUD_W, 0, expanded and H_EXPANDED or H_COLLAPSED)
    clampHud()
    CollapseBtn.Text = expanded and "▴" or "▾"
    SeekBtn.Visible, TimeLeft.Visible, TimeRight.Visible, Row.Visible = expanded, expanded, expanded, expanded
  end)

  -- Tua bằng thanh tiến trình + kéo thả HUD
  local seeking, hudDrag, dragStart, startPos = false, false, nil, nil
  local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
  local function isMove(i) return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch end
  local function seekTo(x)
    if not CurrentMusic or CurrentMusic.TimeLength <= 0 then return end
    local frac = math.clamp((x - SeekBtn.AbsolutePosition.X) / math.max(1, SeekBtn.AbsoluteSize.X), 0, 1)
    CurrentMusic.TimePosition = frac * CurrentMusic.TimeLength
  end

  SeekBtn.InputBegan:Connect(function(i) if isPress(i) then seeking = true seekTo(i.Position.X) end end)
  MusicHUDFrame.InputBegan:Connect(function(i)
    if isPress(i) then hudDrag, dragStart, startPos = true, i.Position, MusicHUDFrame.Position end
  end)
  UIS.InputChanged:Connect(function(i)
    if not MusicHUDFrame.Parent or not isMove(i) then return end
    if seeking then
      seekTo(i.Position.X)
    elseif hudDrag and dragStart then
      local d = i.Position - dragStart
      MusicHUDFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
      clampHud()
    end
  end)
  UIS.InputEnded:Connect(function(i) if isPress(i) then seeking, hudDrag = false, false end end)

  -- Cập nhật thanh tiến trình, thời gian, nút phát/dừng và trạng thái Loop/Shuffle
  HiulzFW.Register("MusicHUD", {
    Priority = 30,
    Interval = 0.15,
    Toggleable = false,
    Tick = function(self)
      if not MusicHUDFrame.Parent or not MusicHUDGui.Enabled or not expanded then return end
      local pos, len = 0, 0
      if CurrentMusic then pos, len = CurrentMusic.TimePosition, CurrentMusic.TimeLength end
      BarFill.Size = UDim2.new(len > 0 and math.clamp(pos / len, 0, 1) or 0, 0, 1, 0)
      TimeLeft.Text, TimeRight.Text = fmtTime(pos), fmtTime(len)
      BtnPlay.Text = (CurrentMusic and CurrentMusic.IsPlaying) and "⏸" or "▶"
      BtnLoop.BackgroundColor3 = IsLooped and ON_COLOR or OFF_COLOR
      BtnShuf.BackgroundColor3 = ShuffleOn and ON_COLOR or OFF_COLOR
    end,
  })
end

-- Cập nhật nhãn đang phát + áp dụng tốc độ cho bài mới
HiulzFW.Register("MusicNow", {
  Priority = 31,
  Interval = 0.5,
  Toggleable = false,
  Tick = function(self)
    if _G.rW15 and _G.rW15.hidden then return end -- [V35] NowLabel nằm trong menu
    local text
    if CurrentMusic then
      if CurrentMusic.PlaybackSpeed ~= CurrentSpeed then CurrentMusic.PlaybackSpeed = CurrentSpeed end
      local nm = CurrentSelectedSongName ~= "" and CurrentSelectedSongName or MusicL("Không xác định")
      text = "🎧 " .. nm .. "\n" .. (CurrentMusic.IsPlaying and "▶ " or "⏸ ")
        .. fmtTime(CurrentMusic.TimePosition) .. " / " .. fmtTime(CurrentMusic.TimeLength)
    else
      text = MusicL("🎧 Chưa phát gì")
    end
    if text ~= self._last then
      self._last = text
      NowLabel:Set(text)
    end
  end,
})

task.defer(function()
  -- [PERF] HUD nhạc: Heartbeat chỉ tồn tại khi HUD đang bật. HUD tắt → Disconnect THẬT (không chỉ return).
  -- HIGH 20Hz | MED 8Hz | LOW: không tạo kết nối (viền tĩnh, chỉ hiện text tên bài).
  local RunService = game:GetService("RunService")
  local hudAcc = 0
  local hudConn
  local interval = _G.HzPerfPick(0.05, 0.125, 0.2)
  local function hudStop()
    if hudConn then
      local c = hudConn
      hudConn = nil
      pcall(function() c:Disconnect() end)
      if type(_G._connections) == "table" then _G._connections[c] = nil end
    end
  end
  local function hudStep()
    if HUDStroke and HUDStroke.Parent and MusicHUDFrame and MusicHUDFrame.Parent and MusicHUDFrame.Visible then
      local t = tick()
      HUDStroke.Color = Color3.fromHSV((t % 5) / 5, 0.8, 1)

      if CurrentMusic and CurrentMusic.IsPlaying then
        local pulse = math.abs(math.sin(t * 4)) * 0.8
        HUDStroke.Thickness = 1.5 + pulse
        MusicIcon.Rotation = math.sin(t * 3) * 10
      else
        HUDStroke.Thickness = 1.5
        MusicIcon.Rotation = 0
      end
      if _G.HzViz then
        pcall(_G.HzViz, t, CurrentMusic ~= nil and CurrentMusic.IsPlaying == true)
      end
    end
  end
  local function hudStart()
    if hudConn or _G.HzPerfLvl == "low" then return end
    if not (MusicHUDGui and MusicHUDGui.Parent and MusicHUDGui.Enabled) then return end
    hudAcc = 0
    hudConn = HzTrack(RunService.Heartbeat:Connect(function(dt)
      hudAcc = hudAcc + (dt or 0)
      if hudAcc < interval then return end
      hudAcc = 0
      -- [PERF] HUD nhạc tắt (kể cả khi menu ẩn: _G.rW15.hidden) → ngắt hẳn kết nối
      if not MusicHUDGui.Enabled or not MusicHUDGui.Parent then hudStop() return end
      hudStep()
    end))
  end
  pcall(function()
    HzTrack(MusicHUDGui:GetPropertyChangedSignal("Enabled"):Connect(function()
      if MusicHUDGui.Enabled then hudStart() else hudStop() end
    end))
  end)
  hudStart()
end)

task.defer(function()
  local lastSound = nil
  local endedConnection = nil
  local lastProfile = nil

  local idleCount = 0 -- [V35]
  local myGen = _G.HzMusicGen
  while true do
    task.wait(idleCount >= 10 and 2 or _G.HzPerfPick(0.5, 0.5, 1)) -- [PERF] idle >= 10 vòng → 2s (mọi nhánh); LOW poll 1s
    if _G.HzMusicGen ~= myGen then
      if endedConnection then endedConnection:Disconnect() end
      break
    end
    local gw = _G.rW15
    if gw and gw.unloaded then break end
    if CurrentMusic then
      idleCount = 0 -- [V35]
      local sName = CurrentSelectedSongName
      if sName == "" or sName == nil then sName = "Không xác định" end
      if MusicHUDLabel.Text ~= sName then MusicHUDLabel.Text = sName end -- [PERF] chỉ Set khi đổi
      if lastProfile ~= sName then
        lastProfile = sName
        HzSetProfile("🎵 " .. tostring(sName))
      end

      if CurrentMusic ~= lastSound then
        lastSound = CurrentMusic
        CurrentMusic.Looped = IsLooped

        if endedConnection then
          endedConnection:Disconnect()
          endedConnection = nil
        end

        endedConnection = CurrentMusic.Ended:Connect(function()
          if not IsLooped then
            task.spawn(function()
              PlayNextSong(1)
            end)
          end
        end)
      else
        if CurrentMusic.Looped ~= IsLooped then
          CurrentMusic.Looped = IsLooped
        end

        if not IsLooped and not CurrentMusic.IsPlaying and CurrentMusic.TimeLength > 0 and (CurrentMusic.TimeLength - CurrentMusic.TimePosition) < 1.5 then
          task.spawn(function()
            PlayNextSong(1)
          end)
        end
      end
    else
      idleCount = idleCount + 1 -- [V35]
      do -- [PERF] chỉ Set khi đổi
        local idleTxt = _G.tR9("Không Có")
        if MusicHUDLabel.Text ~= idleTxt then MusicHUDLabel.Text = idleTxt end
      end
      if lastProfile ~= false then
        lastProfile = false
        HzSetProfile("V41 AutoLoad")
      end
      lastSound = nil
      if endedConnection then
        endedConnection:Disconnect()
        endedConnection = nil
      end
    end
  end
end)

pcall(_G.HzMusicResume)

local TabFeedback = Window:CreateTab("Góp ý", tonumber("81037865260060"))
TabFeedback:CreateSection("Góp ý")
TabFeedback:CreateInput({
  Name = "Gửi góp ý",
  PlaceholderText = "Nội dung góp ý...",
  RemoveTextAfterFocusLost = true,
  Callback = function(text)
    local HttpService = game:GetService("HttpService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    _G.sV7 = _G.sV7 or "BETA"
    _G.lF8 = _G.lF8 or 0
    local now = tick()
    local RATE_LIMIT = 30

    if now - _G.lF8 < RATE_LIMIT then
      local waitSec = math.ceil(RATE_LIMIT - (now - _G.lF8))
      if Notify then
        SafeNotify("Vui lòng đợi", (_G.tR9("Bạn vừa gửi rồi — thử lại sau %d giây.")):format(waitSec))
      else
        pcall(function()
          game:GetService("StarterGui"):SetCore("SendNotification", {Title = _G.tR9("Vui lòng đợi"), Text = (_G.tR9("Thử lại sau %d giây.")):format(waitSec), Duration = 4})
        end)
      end
      return
    end

    if not text or text:match("^%s*$") then
      if Notify then
        SafeNotify("Lỗi", "Nhập nội dung trước khi gửi.")
      else
        pcall(function()
          game:GetService("StarterGui"):SetCore("SendNotification", {Title = _G.tR9("Lỗi"), Text = _G.tR9("Nhập nội dung trước khi gửi."), Duration = 4})
        end)
      end
      return
    end

    local function extract_tag(s, candidates)
      s = s:lower()
      for _, c in ipairs(candidates) do
        if s:find("%["..c.."%]") or s:find("#"..c) or s:find("%("..c.."%)") then
          return c
        end
      end
      return nil
    end

    local function remove_all_tags(s)
      s = s:gsub("%[(.-)%]", ""):gsub("#(%w+)", ""):gsub("%((.-)%)", "")
      s = s:gsub("^%s+", ""):gsub("%s+$", "")
      return s
    end

    local typeCandidates = {"bug", "idea", "other"}
    local prioCandidates = {"low", "normal", "high"}

    local lowerText = text:lower()
    local detectedType = extract_tag(lowerText, typeCandidates) or "other"
    local detectedPrio = extract_tag(lowerText, prioCandidates) or "normal"

    local displayType = ({bug="Bug", idea="Idea", other="Other"})[detectedType] or "Other"
    local displayPrio = ({low="Low", normal="Normal", high="High"})[detectedPrio] or "Normal"

    local cleaned = remove_all_tags(text)

    local placeName = tostring(game.PlaceId)
    pcall(function()
      local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
      if ok and info and info.Name then placeName = info.Name end
    end)

    local uptimeText = "N/A"
    if _G.sT1 and type(_G.sT1) == "number" then
      local uptime = math.floor(tick() - _G.sT1)
      if uptime < 0 then uptime = 0 end
      local hh = math.floor(uptime / 3600)
      local mm = math.floor((uptime % 3600) / 60)
      local ss = math.floor(uptime % 60)
      uptimeText = string.format("%02d:%02d:%02d", hh, mm, ss)
    end

    local scriptVer = tostring(_G.sV7 or "unknown")

    local playerName = LocalPlayer and LocalPlayer.Name or "Unknown"
    local playerId = LocalPlayer and tostring(LocalPlayer.UserId) or "Unknown"

    -- Author webhook = tên + avatar Roblox của người chơi
    local authorName = playerName
    pcall(function()
      if LocalPlayer then
        local dn = tostring(LocalPlayer.DisplayName or "")
        if dn ~= "" and dn ~= LocalPlayer.Name then
          authorName = dn .. " (@" .. LocalPlayer.Name .. ")"
        end
      end
    end)
    authorName = authorName:sub(1, 256)
    local authorIcon = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. playerId .. "&width=150&height=150&format=png"
    pcall(function()
      if LocalPlayer then
        local body = game:HttpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. playerId .. "&size=150x150&format=Png&isCircular=false")
        local d = HttpService:JSONDecode(body)
        local u = d and d.data and d.data[1] and d.data[1].imageUrl
        if type(u) == "string" and u:sub(1, 8) == "https://" then authorIcon = u end
      end
    end)

    -- [V24] Ngôn ngữ embed: "auto" = theo ngôn ngữ script (VN -> Việt, nước khác kể cả pt -> English);
    -- đổi thành "en" hoặc "vi" để cố định cho mọi người dùng.
    local EMBED_LANG = "auto"
    local embedLang = EMBED_LANG
    if embedLang ~= "en" and embedLang ~= "vi" then
      embedLang = "vi"
      pcall(function()
        if type(_G.lG10) == "function" and _G.lG10() ~= "vi" then embedLang = "en" end
      end)
    end
    local function T(vi, en) return embedLang == "en" and en or vi end

    -- [V23] Chuẩn bị dữ liệu embed
    local MAX_DESC = 1500
    if #cleaned > MAX_DESC then
      cleaned = cleaned:sub(1, MAX_DESC) .. "\n\n" .. T("[...đã cắt bớt...]", "[...truncated...]")
    end
    cleaned = cleaned:gsub("\n\n\n+", "\n\n")

    local function mdSafe(s, maxLen)
      s = tostring(s or ""):gsub("([%[%]%(%)%*_`~|>\\])", "\\%1")
      if maxLen and #s > maxLen then s = s:sub(1, maxLen) .. "…" end
      return s
    end

    local TYPE_STYLE = {
      bug   = {icon = "🐛", color = 0xED4245},
      idea  = {icon = "💡", color = 0x57F287},
      other = {icon = "📩", color = 0x00FFFF},
    }
    local PRIO_ICON = {low = "🟢", normal = "🟡", high = "🔴"}
    local style = TYPE_STYLE[detectedType] or TYPE_STYLE.other

    local senderVal = mdSafe(playerName, 40)
    if tonumber(playerId) then
      senderVal = ("[%s](https://www.roblox.com/users/%s/profile)\n`%s`"):format(mdSafe(playerName, 40), playerId, playerId)
    end

    local gameVal = ("%s\n`%s`"):format(mdSafe(placeName, 50), tostring(game.PlaceId))
    pcall(function()
      gameVal = ("[%s](https://www.roblox.com/games/%s)\n`%s`"):format(mdSafe(placeName, 50), tostring(game.PlaceId), tostring(game.PlaceId))
    end)

    local serverVal = "N/A"
    pcall(function()
      serverVal = ("%d/%d " .. T("người", "players")):format(#Players:GetPlayers(), Players.MaxPlayers)
    end)

    local deviceVal = "PC"
    pcall(function()
      local UIS = game:GetService("UserInputService")
      local icon = "💻"
      if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        deviceVal, icon = "Mobile", "📱"
      elseif UIS.GamepadEnabled and not UIS.KeyboardEnabled then
        deviceVal, icon = "Console", "🎮"
      end
      deviceVal = icon .. " " .. deviceVal
    end)

    local perfVal = "N/A"
    pcall(function()
      perfVal = ("`%d` FPS\n`%d` ms"):format(math.floor(tonumber(_G.cF2) or 0), math.floor(tonumber(_G.cP3) or 0))
    end)

    local payload = {
      embeds = {{
        author = {
          name = authorName,
          url = tonumber(playerId) and ("https://www.roblox.com/users/" .. playerId .. "/profile") or nil,
          icon_url = authorIcon
        },
        title = ("%s %s  ·  %s %s"):format(style.icon, displayType, PRIO_ICON[detectedPrio] or "🟡", displayPrio),
        description = "> " .. (cleaned:gsub("\n", "\n> ")),
        color = style.color,
        fields = {
          {name = T("👤 Người gửi", "👤 Sender"), value = senderVal, inline = true},
          {name = "🎮 Game", value = gameVal, inline = true},
          {name = "👥 Server", value = serverVal, inline = true},
          {name = T("📱 Thiết bị", "📱 Device"), value = deviceVal, inline = true},
          {name = T("📊 Hiệu năng", "📊 Performance"), value = perfVal, inline = true},
          {name = "⏱ Uptime", value = "`" .. uptimeText .. "`", inline = true},
        },
        thumbnail = {
          url = "https://cdn.discordapp.com/attachments/1448545962393075763/1482222266845495346/anime-gif-collection-v0-x7rt5z1qx90e1.gif?ex=69b62a8e&is=69b4d90e&hm=1c4a37656193725cfc55af4257ab823921fc5cdcd3d2956b1fac52952ec59ee7&"
        },
        footer = { text = "Support • " .. scriptVer },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
      }}
    }

    local encoded = HttpService:JSONEncode(payload)
    local success, sendErr = false, nil

    local actualWebhookUrl = "https://hiulzweb.vercel.app/api/feedback"
    local mySecretKey = tostring(_G.HzFeedbackKey)

    local myHeaders = {
      ["Content-Type"] = "application/json",
      ["x-api-key"] = mySecretKey
    }

    if actualWebhookUrl and actualWebhookUrl ~= "" and actualWebhookUrl:find("http") then
      success, sendErr = HzPostJson(actualWebhookUrl, myHeaders, encoded)
      if not success and _G.aa3542001e064bc52 then
        pcall(_G.aa3542001e064bc52, "Webhook: " .. tostring(sendErr), "ERROR")
      end
    else
      if Notify then
        SafeNotify("Lỗi Webhook", "Không thể lấy Webhook thực từ server.\nVui lòng kiểm tra lại đường dẫn!")
      end
      return
    end

    if success then
      _G.lF8 = tick()
      if Notify then
        SafeNotify("Gửi thành công", "Cảm ơn!\nNội dung đã được gửi tới Discord.")
      else
        pcall(function()
          game:GetService("StarterGui"):SetCore("SendNotification", {Title = _G.tR9("Thành công"), Text = _G.tR9("Nội dung đã gửi tới Discord."), Duration = 4})
        end)
      end
    else
      if Notify then
        SafeNotify("Lỗi gửi", "Không thể gửi. Executor có thể không hỗ trợ request.")
      else
        pcall(function()
          game:GetService("StarterGui"):SetCore("SendNotification", {Title = _G.tR9("Lỗi"), Text = _G.tR9("Không thể gửi. Executor có thể không hỗ trợ request."), Duration = 4})
        end)
      end
    end
  end,
})

-- [TAB TỐI ƯU HÓA - Phiên bản nâng cấp]
local TabOptimize = Window:CreateTab("Tối ưu", tonumber("78754569296388"))
_G.HzOptBuildA = function() -- [V35] nửa đầu tab Tối ưu (dựng lazy cùng nửa FPS/Ping)
TabOptimize:CreateSection("Hiệu suất")

local _fixLagLoaded = false

local function safeNotify(title, text)
  SafeNotify(title, text)
end

TabOptimize:CreateButton({
  Name = "Fix lag", Callback = function()
  if _fixLagLoaded then
    safeNotify("Fix Lag Turbo", "Script đã được load trước đó.")
    return
  end
  safeNotify("Fix Lag Turbo", "Đang load script...")
  local ok, err = pcall(function()
    local success, res = pcall(function()
      return game:HttpGet("https://raw.githubusercontent.com/TurboLite/Script/main/FixLag.lua")
    end)
    if not success or not res or res == "" then
      error("Không tải được nội dung script từ URL.")
    end
    local fn, loadErr = loadstring(res)
    if not fn then error("loadstring lỗi: "..tostring(loadErr)) end
    fn()
  end)
  if ok then
    _fixLagLoaded = true
    safeNotify("Fix Lag Turbo", "Hoàn thành load script!")
  else
    safeNotify("Fix Lag Turbo - Lỗi", tostring(err))
  end
end })

_G.feb30fee1c45c6a5e(TabOptimize, "optimize")

local _originalState = {
  parts = {},
  decals = {},
  lighting = {},
  terrain = {}
}
local _applied = false

-- [PERF] Cache workspace:GetDescendants(): dùng lại tối đa 30s; workspace.ChildAdded đánh dấu bẩn → quét lại.
-- skipOthers = true: loại mọi thứ thuộc character của người chơi KHÁC (không đụng nhân vật người khác).
_G.HzWsDesc = (function()
  local cache, stamp, dirty, conn = nil, 0, true, nil
  local Players = game:GetService("Players")
  local function isOtherChar(inst, me)
    local p = inst.Parent
    while p and p ~= workspace do
      if p:IsA("Model") and p ~= me and Players:GetPlayerFromCharacter(p) then return true end
      p = p.Parent
    end
    return false
  end
  return function(skipOthers)
    if not conn then
      pcall(function() conn = workspace.ChildAdded:Connect(function() dirty = true end) end)
      if conn and HzTrack then pcall(HzTrack, conn) end
    end
    if dirty or not cache or (os.clock() - stamp) > 30 then
      cache, stamp, dirty = workspace:GetDescendants(), os.clock(), false
    end
    if not skipOthers then return cache end
    local me = Players.LocalPlayer and Players.LocalPlayer.Character
    local out, n = {}, 0
    for i = 1, #cache do
      local d = cache[i]
      if not isOtherChar(d, me) then out[#out + 1] = d end
      n = n + 1
      if n % 2000 == 0 then task.wait() end
    end
    return out
  end
end)()

TabOptimize:CreateButton({
  Name = "Giảm đồ họa",
  Callback = function()
    if _applied then
      safeNotify("Tối ưu", "Đã giảm đồ họa — bấm Khôi phục để trả lại.")
      return
    end

    safeNotify("Tối ưu", "Đang dọn đồ họa (vài giây)...")

    task.spawn(function()
      local ok, err = pcall(function()
        local workspaceDesc = _G.HzWsDesc(true) -- [PERF] cache + bỏ qua character người khác
        _G.HzGfxTouched = true -- [PERF] người dùng đã bấm: được phép khôi phục Lighting/Quality lúc unload
        local lighting = game:GetService("Lighting")
        local terrain = workspace:FindFirstChildOfClass("Terrain")

        pcall(function()
          _originalState.lighting.GlobalShadows = lighting.GlobalShadows
          _originalState.lighting.FogEnd = lighting.FogEnd
          _originalState.lighting.EnvironmentDiffuseScale = lighting.EnvironmentDiffuseScale
          _originalState.lighting.EnvironmentSpecularScale = lighting.EnvironmentSpecularScale

          _originalState.lighting.effects = {}

          for _, child in ipairs(lighting:GetDescendants()) do
            if child:IsA("PostEffect") or child:IsA("BlurEffect") or child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("BloomEffect") or child:IsA("DepthOfFieldEffect") or child:IsA("Atmosphere") or child:IsA("Clouds") then
               if child:IsA("Atmosphere") or child:IsA("Clouds") then
                _originalState.lighting.effects[child] = { Parent = child.Parent }
                pcall(function() child.Parent = nil end)
              else
                _originalState.lighting.effects[child] = { Enabled = child.Enabled }
                pcall(function() child.Enabled = false end)
              end
            end
          end

          lighting.GlobalShadows = false
          lighting.FogEnd = 9e9
          lighting.EnvironmentDiffuseScale = 0
          lighting.EnvironmentSpecularScale = 0
        end)

        if terrain then
          pcall(function()
            _originalState.terrain = {
              Decoration = terrain.Decoration,
              WaterWaveSize = terrain.WaterWaveSize,
              WaterWaveSpeed = terrain.WaterWaveSpeed
            }
            terrain.Decoration = false
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
          end)
        end

        local count = 0
        for _, v in ipairs(workspaceDesc) do
          if v:IsA("BasePart") and not v:IsA("MeshPart") then
            if not _originalState.parts[v] then
              _originalState.parts[v] = {
                Material = v.Material,
                Reflectance = v.Reflectance,
                Transparency = v.Transparency,
                CastShadow = v.CastShadow
              }
            end
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
            pcall(function() v.CastShadow = false end)

            if v.Name:lower():find("glass") or v.Name:lower():find("window") then
              v.Transparency = math.max(v.Transparency, 0.25)
            end

          elseif v:IsA("Decal") or v:IsA("Texture") then
            if not _originalState.decals[v] then
              _originalState.decals[v] = { Transparency = v.Transparency }
            end
            v.Transparency = 1

          elseif v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") or v:IsA("Sparkles") or v:IsA("Fire") or v:IsA("Smoke") then
            if not _originalState.parts[v] then
              _originalState.parts[v] = { Enabled = v.Enabled }
            end
            v.Enabled = false

          elseif v:IsA("Sound") then
            if not _originalState.parts[v] then
              _originalState.parts[v] = { Volume = v.Volume, Playing = v.IsPlaying }
            end
            v.Volume = 0
            if v.IsPlaying then pcall(function() v:Pause() end) end
          end

          count = count + 1
          if count % 500 == 0 then
            task.wait()
          end
        end

        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        _applied = true
      end)

      if ok then
        safeNotify("Tối ưu", "Đã dọn xong!\n Tắt bóng, xóa cỏ 3D & giảm chất lượng tối đa.")
      else
        safeNotify("Tối ưu hóa - Lỗi", tostring(err))
      end
    end)
  end
})

TabOptimize:CreateButton({
  Name = "Khôi phục",
  Callback = function()
    if not _applied then
      safeNotify("Khôi phục", "Chưa có cấu hình nào bị giảm để khôi phục.")
      return
    end

    safeNotify("Khôi phục", "Đang khôi phục (Sẽ mất vài giây)...")

    task.spawn(function()
      local ok, err = pcall(function()
        local count = 0

        for obj, data in pairs(_originalState.parts) do
          if obj and obj.Parent then
            if data.Material then pcall(function() obj.Material = data.Material end) end
            if data.Reflectance then pcall(function() obj.Reflectance = data.Reflectance end) end
            if data.Transparency then pcall(function() obj.Transparency = data.Transparency end) end
            if data.CastShadow ~= nil then pcall(function() obj.CastShadow = data.CastShadow end) end
            if data.Enabled ~= nil then pcall(function() obj.Enabled = data.Enabled end) end
            if data.Volume then pcall(function() obj.Volume = data.Volume end) end
            if data.Playing ~= nil then
              pcall(function() if data.Playing and obj.Play then obj:Play() end end)
            end
          end
          count = count + 1
          if count % 500 == 0 then task.wait() end
        end

        for obj, data in pairs(_originalState.decals) do
          if obj and obj.Parent then
            if data.Transparency then pcall(function() obj.Transparency = data.Transparency end) end
          end
          count = count + 1
          if count % 500 == 0 then task.wait() end
        end

        local lighting = game:GetService("Lighting")
        if _originalState.lighting.GlobalShadows ~= nil then pcall(function() lighting.GlobalShadows = _originalState.lighting.GlobalShadows end) end
        if _originalState.lighting.FogEnd ~= nil then pcall(function() lighting.FogEnd = _originalState.lighting.FogEnd end) end
        if _originalState.lighting.EnvironmentDiffuseScale ~= nil then pcall(function() lighting.EnvironmentDiffuseScale = _originalState.lighting.EnvironmentDiffuseScale end) end
        if _originalState.lighting.EnvironmentSpecularScale ~= nil then pcall(function() lighting.EnvironmentSpecularScale = _originalState.lighting.EnvironmentSpecularScale end) end

        if _originalState.lighting.effects then
          for effect, data in pairs(_originalState.lighting.effects) do
            if effect then
              if data.Parent then pcall(function() effect.Parent = data.Parent end) end
              if data.Enabled ~= nil then pcall(function() effect.Enabled = data.Enabled end) end
            end
          end
        end

        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain and _originalState.terrain then
          local td = _originalState.terrain
          if td.Decoration ~= nil then pcall(function() terrain.Decoration = td.Decoration end) end
          if td.WaterWaveSize ~= nil then pcall(function() terrain.WaterWaveSize = td.WaterWaveSize end) end
          if td.WaterWaveSpeed ~= nil then pcall(function() terrain.WaterWaveSpeed = td.WaterWaveSpeed end) end
        end

        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)

        _originalState = { parts = {}, decals = {}, lighting = {}, terrain = {} }
        _applied = false
      end)

      if ok then
        safeNotify("Khôi phục", "Đã khôi phục toàn bộ cấu hình gốc thành công.")
      else
        safeNotify("Khôi phục - Lỗi", tostring(err))
      end
    end)
  end
})

TabOptimize:CreateButton({
  Name = "Dọn chat",
  Callback = function()
    pcall(function()
      local chatFrame = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Chat")
      if chatFrame then
        local scroller = chatFrame:FindFirstChild("Frame_MessageLogDisplay", true)
        if scroller and scroller:FindFirstChild("Scroller") then
          for _, msg in pairs(scroller.Scroller:GetChildren()) do
            if msg:IsA("Frame") then
              msg:Destroy()
            end
          end
          Notify("Tối ưu", "Đã xóa toàn bộ tin nhắn rác trong khung chat!")
        else
          Notify("Tối ưu", "Không tìm thấy dữ liệu chat!")
        end
      else
        Notify("Tối ưu", "Game sử dụng TextChatService mới hoặc Custom Chat!")
      end
    end)
  end
})
end -- [V35] hết _G.HzOptBuildA
-- ==========================================
-- HỆ THỐNG FPS/PING HUD
-- ==========================================
local HUD_NAME = HzN.hud
_G.b655ac11a998f805f = _G.b655ac11a998f805f or false

local statusGui, statusFrame
local connRender
local LocalPlayer = Players.LocalPlayer

local function getSafeGui()
  if type(GetSafeGui) == "function" then
    local ok, g = pcall(GetSafeGui)
    if ok and g then return g end
  end
  if Players.LocalPlayer then
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then return playerGui end
    local ok, pg = pcall(function() return Players.LocalPlayer:WaitForChild("PlayerGui", 5) end)
    if ok and pg then return pg end
  end
  return game:GetService("CoreGui")
end

local function destroyStatusHUD()
  pcall(function()
    if connRender and connRender.Connected then
      connRender:Disconnect()
      connRender = nil
    end

    if statusGui and statusGui.Parent then
       statusGui:Destroy()
    end

    local safe = (type(GetSafeGui) == "function" and pcall(GetSafeGui) and getSafeGui()) or getSafeGui()
    if safe and safe.FindFirstChild then
      local existing = safe:FindFirstChild(HUD_NAME)
      if existing then existing:Destroy() end
    end

    local coreExisting = game:GetService("CoreGui"):FindFirstChild(HUD_NAME)
    if coreExisting then coreExisting:Destroy() end

    statusGui, statusFrame = nil, nil
  end)
end

_G.dH6 = destroyStatusHUD

local lblTime, lblFPS, lblPing

local function createStatusHUD()
  pcall(function()
    destroyStatusHUD()

    local safeGui = getSafeGui()

    statusGui = Instance.new("ScreenGui")
    statusGui.Name = HUD_NAME
    statusGui.IgnoreGuiInset = true
    statusGui.ResetOnSpawn = false
    statusGui.Parent = safeGui

    statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(0, 320, 0, 24)
    statusFrame.AnchorPoint = Vector2.new(1, 0)
    statusFrame.Position = UDim2.new(1, -8, 0, 8)
    statusFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    statusFrame.BackgroundTransparency = 0.35
    statusFrame.BorderSizePixel = 0
    statusFrame.ZIndex = 9999
    statusFrame.Parent = statusGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = statusFrame

    local layout = Instance.new("UIListLayout", statusFrame)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)

    local function createFixedLabel(name, width, order)
      local lbl = Instance.new("TextLabel")
      lbl.Name = name
      lbl.Size = UDim2.new(0, width, 1, 0)
      lbl.BackgroundTransparency = 1
      lbl.Font = Enum.Font.GothamSemibold
      lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
      lbl.TextSize = 13
      lbl.TextXAlignment = Enum.TextXAlignment.Center
      lbl.LayoutOrder = order
      lbl.ZIndex = 10000
      lbl.Parent = statusFrame
      return lbl
    end

    lblTime = createFixedLabel("Time", 85, 1)
    local sep1 = createFixedLabel("Sep1", 10, 2)
    sep1.Text = "|"
    lblFPS = createFixedLabel("FPS", 65, 3)
    local sep2 = createFixedLabel("Sep2", 10, 4)
    sep2.Text = "|"
    lblPing = createFixedLabel("Ping", 130, 5)

    local smoothed = 60
    local updateAcc = 0 -- [V35]
    local startTime = tick()
    local pingUpdateTimer = 2
    local lastFpsText = "60"
    local lastPingText = "??ms"
    local lastCv = 0
    local HUD_INT = _G.HzPerfPick(0.5, 1, 2) -- [PERF] ghi label: HIGH 0.5s | MED 1s | LOW 2s
    local lastT, lastF, lastP -- [PERF] chỉ Set khi text đổi

    if connRender and connRender.Connected then
      connRender:Disconnect()
      connRender = nil
    end

    connRender = RunService.Heartbeat:Connect(function(dt) -- [PERF] RenderStepped → Heartbeat
      if not _G.b655ac11a998f805f or not statusFrame or not statusFrame.Parent then
        destroyStatusHUD()
        return
      end

      if dt > 0 then
        local fps = 1 / dt
        smoothed = smoothed * 0.85 + fps * 0.15
      end

      pingUpdateTimer = pingUpdateTimer + dt -- [V35] cộng trước throttle để chu kỳ 2s đúng
      updateAcc = updateAcc + dt
      if updateAcc < HUD_INT then return end -- [PERF] chu kỳ theo mức máy
      updateAcc = 0
      if pingUpdateTimer >= 2 then
        pingUpdateTimer = 0
        lastFpsText = tostring(math.floor(smoothed + 0.5))

        local pingVal = nil
        pcall(function()
          local stats = game:GetService("Stats")
          if stats and stats:FindFirstChild("Network") and stats.Network:FindFirstChild("ServerStatsItem") then
            local s = stats.Network.ServerStatsItem
            if s["DataPing"] then pingVal = math.floor(s["DataPing"]:GetValue() + 0.5) end
          end
        end)
        pcall(function()
          if (not pingVal or pingVal <= 0) and LocalPlayer and LocalPlayer.GetNetworkPing then
            local p = LocalPlayer:GetNetworkPing()
            if type(p) == "number" then pingVal = math.floor(p * 1000 + 0.5) end
          end
        end)
        lastPingText = pingVal and (tostring(pingVal) .. "ms") or "??ms"

        local diff = 60 - smoothed
        if diff > 0 then lastCv = math.floor(math.min(100, (diff / 60) * 100) + 0.5) else lastCv = 0 end
      end

      local now = tick()
      local elapsed = math.floor(now - startTime + 0.5)
      local hours = math.floor(elapsed / 3600)
      local mins = math.floor((elapsed % 3600) / 60)
      local secs = elapsed % 60
      local timestr = string.format("%02d:%02d:%02d", hours, mins, secs)

      -- [PERF] cache[h]==text: không ghi Text nếu không đổi
      local tT = "Time: " .. timestr
      local tF = "FPS: " .. lastFpsText
      local tP = string.format("Ping: %s (%02d%%CV)", lastPingText, lastCv)
      pcall(function()
        if tT ~= lastT then lastT = tT; lblTime.Text = tT end
        if tF ~= lastF then lastF = tF; lblFPS.Text = tF end
        if tP ~= lastP then lastP = tP; lblPing.Text = tP end
      end)
    end)
  end)
end
-- [PHẦN TOGGLE ĐÃ SỬA]
_G.HzLazyTab(TabOptimize, "Tối ưu", function() -- [V35]
_G.HzOptBuildA()
TabOptimize:CreateSection("FPS / Ping")
TabOptimize:CreateToggle({
  Name = " FPS / Ping",
  Icon = tonumber("8024385928"),
  CurrentValue = _G.b655ac11a998f805f,
  Callback = function(val)
    _G.b655ac11a998f805f = val
    if val then
      createStatusHUD()
      -- Gửi log vào khung Mini Nhật Ký
      if _G.aa3542001e064bc52 then
        task.wait(0.1) -- Đợi 1 chút để FPS cập nhật con số thực
        _G.aa3542001e064bc52("Đã bật HUD FPS/PING | FPS hiện tại: " .. _G.cF2, "SUCCESS")
      end
    else
      destroyStatusHUD()
    end
  end,
})

-- Tự động bật nếu trạng thái trước đó là true
if _G.b655ac11a998f805f then
  createStatusHUD()
end
end, _G.b655ac11a998f805f == true) -- [V35] HUD đã bật từ trước → dựng ngay

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local placeId = tostring(game.PlaceId or 0)

local function getLocal()
  if Players.LocalPlayer then return Players.LocalPlayer end
  local start = tick()
  while tick() - start < 5 do
    if Players.LocalPlayer then return Players.LocalPlayer end
    task.wait(0.1)
  end
  return Players.LocalPlayer
end

local function safeSetClipboard(text)
  local ok, _ = pcall(function()
    if setclipboard then setclipboard(text) end
    if syn and syn.set_clipboard then syn.set_clipboard(text) end
    if set_clipboard then set_clipboard(text) end
    if clipboard and clipboard.set then clipboard.set(text) end
  end)
  return ok
end

local function doRequest(url)
  local req = (syn and syn.request) or (http and http.request) or http_request or request
  if req then
    local ok, res = pcall(function()
      return req({ Url = url, Method = "GET" })
    end)
    if ok and res then
      if res.Body and res.Body ~= "" then return res.Body end
      if res.body and res.body ~= "" then return res.body end
    end
  end

  local ok2, body = pcall(function() return game:HttpGet(url, true) end)
  if ok2 and body and body ~= "" then return body end

  return nil
end

local function getServerPage(cursor)
  local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?limit=100"
  if cursor and cursor ~= "" then
    url = url .. "&cursor=" .. HttpService:UrlEncode(tostring(cursor))
  end
  local body = doRequest(url)
  if not body then return nil end
  local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
  if ok and type(data) == "table" then return data end
  return nil
end

local function collectCandidateServers(maxPages, onPage)
  maxPages = tonumber(maxPages) or 8
  local servers = {}
  local cursor = nil
  local got = 0
  if onPage then pcall(onPage, 0, maxPages, false) end
  for i = 1, maxPages do
    local page = getServerPage(cursor)
    if not page then break end
    got = i
    if page.data and type(page.data) == "table" then
      for _, s in ipairs(page.data) do
        if s.id and tostring(s.id) ~= tostring(game.JobId) and s.playing and s.maxPlayers then
          table.insert(servers, s)
        end
      end
    end
    if onPage then pcall(onPage, i, maxPages, false) end
    cursor = page.nextPageCursor
    if not cursor or cursor == "" then break end
  end
  if onPage then pcall(onPage, got, maxPages, true) end
  return servers
end

pcall(function() math.randomseed(tick() % 2147483647) end)

local TabServer = Window:CreateTab("Server", tonumber("9692125126"))
TabServer:CreateDivider({ text = "Máy chủ" })
TabServer:CreateSection("Máy chủ")
TabServer.ProgTop = TabServer:CreateProgress({ name = "Tiến trình thu thập server", range = { 0, 8 }, value = 0, format = HzFmtN })
TabServer.OnPage = function(i, maxP, done)
  maxP = math.max(1, tonumber(maxP) or 8)
  i = math.max(0, tonumber(i) or 0)
  for _, h in ipairs({ TabServer.ProgTop, TabServer.ProgExport }) do
    pcall(function()
      h:SetRange(0, (done and i > 0) and i or maxP)
      if i == 0 and not done then h:SetIndeterminate(true) else h:Set(i) end
    end)
  end
end

TabServer:CreateButton({
  Name = "🔁 Đổi server",
  Callback = function()
    Notify("Server", "Tìm server khác...")
    local servers = collectCandidateServers(nil, TabServer.OnPage)
    if not servers or #servers == 0 then
      Notify("Server", "Không tìm được server (cần mở HTTP hoặc thử lại).")
      return
    end

    local available = {}
    for _, s in ipairs(servers) do
      if tonumber(s.playing) and tonumber(s.maxPlayers) and tonumber(s.playing) < tonumber(s.maxPlayers) then
        table.insert(available, s)
      end
    end

    if #available == 0 then
      Notify("Server", "Tạm thời không có server trống, chọn ngẫu nhiên...")
      available = servers
    end

    local chosen = available[math.random(1, #available)]
    if not chosen or not chosen.id then
      Notify("Server", "Không thể chọn server.")
      return
    end

    Notify("Server", "Đang chuyển sang server: " .. tostring(chosen.id))
    local LocalPlayer = getLocal()
    if not LocalPlayer then
      Notify("Server", "Lỗi: LocalPlayer chưa sẵn sàng.")
      return
    end
    pcall(function()
      if _G.HzQueueHubReload then pcall(_G.HzQueueHubReload, "server hop") end
      TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(chosen.id), LocalPlayer)
    end)
  end
})

TabServer:CreateButton({
  Name = "🔍 Server vắng nhất",
  Callback = function()
    Notify("Server", "Tìm server ít người nhất...")
    local servers = collectCandidateServers(nil, TabServer.OnPage)
    if not servers or #servers == 0 then
      Notify("Server", "Không tìm được server (cần mở HTTP hoặc thử lại).")
      return
    end

    local best = nil
    for _, s in ipairs(servers) do
      if s.id and s.playing then
        if not best or (tonumber(s.playing) or 0) < (tonumber(best.playing) or 0) then
          best = s
        end
      end
    end

    if not best or not best.id then
      Notify("Server", "Không tìm được server phù hợp.")
      return
    end

    Notify("Server", string.format(_G.tR9("Đang join server %s (%d/%d)"), tostring(best.id), tonumber(best.playing) or 0, tonumber(best.maxPlayers) or 0))
    local LocalPlayer = getLocal()
    if not LocalPlayer then
      Notify("Server", "Lỗi: LocalPlayer chưa sẵn sàng.")
      return
    end
    pcall(function()
      if _G.HzQueueHubReload then pcall(_G.HzQueueHubReload, "server hop") end
      TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(best.id), LocalPlayer)
    end)
  end
})

TabServer:CreateButton({
  Name = "⤴️ Vào lại",
  Callback = function()
    local jid = tostring(game.JobId or "")
    if not jid or jid == "" then
      Notify("Server", "Không thể lấy JobId hiện tại.")
      return
    end
    Notify("Server", "Đang join lại server hiện tại: " .. jid)
    local LocalPlayer = getLocal()
    if not LocalPlayer then
      Notify("Server", "Lỗi: LocalPlayer chưa sẵn sàng.")
      return
    end
    if _G.HzQueueHubReload then pcall(_G.HzQueueHubReload, "rejoin") end
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, jid, LocalPlayer) end)
  end
})

TabServer:CreateButton({
  Name = "📋 Copy JobID",
  Callback = function()
    local jid = tostring(game.JobId or "")
    if jid == "" then
      Notify("Server", "Không thể lấy JobID hiện tại.")
      return
    end
    if safeSetClipboard(jid) then
      Notify("Server", "Đã copy JobID vào clipboard.")
    else
      Notify("Server", "Không thể copy (executor không hỗ trợ). JobID: " .. jid)
    end
  end
})

TabServer:CreateDivider({ text = "JobID" })
TabServer:CreateLabel("JobID: " .. tostring(game.JobId or ""))

local TargetJobID = ""
TabServer:CreateInput({
  Name = "JobID",
  PlaceholderText = "Dán JobID...",
  RemoveTextAfterFocusLost = false,
  Callback = function(Text)
    TargetJobID = Text
  end
})

TabServer:CreateButton({
  Name = "Vào server",
  Callback = function()
    local cleanJobID = string.match(TargetJobID, "^%s*(.-)%s*$")

    if cleanJobID == "" then
      Notify("Server", "❌ Vui lòng nhập JobID trước!")
      return
    end

    if string.len(cleanJobID) < 10 then
      Notify("Server", "❌ JobID không hợp lệ! Vui lòng kiểm tra lại.")
      return
    end

    Notify("Server", "⏳ Đang thử kết nối vào JobID: " .. cleanJobID)

    local LocalPlayer = getLocal()
    if not LocalPlayer then
      Notify("Server", "❌ Lỗi: LocalPlayer chưa sẵn sàng.")
      return
    end

    local success, err = pcall(function()
      if _G.HzQueueHubReload then pcall(_G.HzQueueHubReload, "join JobID") end
      TeleportService:TeleportToPlaceInstance(game.PlaceId, cleanJobID, LocalPlayer)
    end)

    if not success then
      Notify("Server", "❌ Lỗi: JobID này không tồn tại hoặc KHÔNG thuộc game này!")
    else
      task.delay(4, function()
        Notify("Server", "⚠️ Cảnh báo: Nếu chưa được dịch chuyển, JobID có thể KHÔNG thuộc game này hoặc server đã đầy!")
      end)
    end
  end
})

TabServer:CreateButton({
  Name = "📎 Code vào sever này! ",
  Callback = function()
    local jid = tostring(game.JobId or "")
    local code
    if jid == "" then
      code = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "<JOBID HERE>", game.Players.LocalPlayer)', placeId)
    else
      code = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s", game.Players.LocalPlayer)', placeId, jid)
    end

    if safeSetClipboard(code) then
       Notify("Server", "Đã copy teleport code (current) vào clipboard.")
    else
      Notify("Server", "Không thể copy (executor không hỗ trợ).\nTeleport code: " .. code)
    end
  end
})

TabServer:CreateButton({
  Name = "🗂️ Xuất danh sách server",
  Callback = function()
    Notify("Server", "Thu thập danh sách server (có thể mất vài giây)...")
    local servers = collectCandidateServers(6, TabServer.OnPage)
    if not servers or #servers == 0 then
      Notify("Server", "Không lấy được server để copy.")
      return
    end
    local ok, j = pcall(function() return HttpService:JSONEncode(servers) end)
    if not ok or not j then
      Notify("Server", "Không thể mã hoá JSON.")
      return
    end
    if safeSetClipboard(j) then
      Notify("Server", "Đã copy danh sách server (JSON) vào clipboard.")
    else
      Notify("Server", "Không thể copy (executor không hỗ trợ). Bắt đầu in JSON trong console...")
      print(j)
    end
  end
})
TabServer.ProgExport = TabServer:CreateProgress({ name = "Tiến trình thu thập server", range = { 0, 6 }, value = 0, format = HzFmtN })

  do
    local TabLog = Window:CreateTab("Nhật Ký", tonumber("4871684504"))
    TabLog:CreateSection("Dòng chảy nhật ký")
    local con = TabLog:CreateConsole({ Name = "Nhật ký", Height = 220, Follow = true, MaxLines = 300 })
    pcall(function()
      if type(_G.d5020228e3d6e626e) == "function" then
        for _, line in ipairs(_G.d5020228e3d6e626e()) do con:Append(line) end
      end
      if type(_G.ceb25e14eddadce3c) ~= "table" then _G.ceb25e14eddadce3c = {} end
      table.insert(_G.ceb25e14eddadce3c, function(line) con:Append(line) end)
    end)

    local LBL_ALL  = HzUiL("◎ Xem tất tần tật")
    local LBL_ERR  = HzUiL("✖ Chỉ bắt lỗi")
    local LBL_WARN = HzUiL("⚠ Cảnh báo trở lên")
    local LBL_OK   = HzUiL("✔ Chỉ việc êm xuôi")
    local LBL_DEV  = HzUiL("🖥 Mở bảng F9 / F12")
    local LENS_MAP = { [LBL_ALL] = "ALL", [LBL_ERR] = "ERROR", [LBL_WARN] = "WARN", [LBL_OK] = "SUCCESS", [LBL_DEV] = "DEV" }
    LENS_MAP.match = function(pick)
      if type(pick) ~= "string" then return nil end
      if LENS_MAP[pick] then return LENS_MAP[pick] end
      if string.find(pick, "◎", 1, true) then return "ALL" end
      if string.find(pick, "✖", 1, true) then return "ERROR" end
      if string.find(pick, "⚠", 1, true) then return "WARN" end
      if string.find(pick, "✔", 1, true) then return "SUCCESS" end
      if string.find(pick, "🖥", 1, true) then return "DEV" end
      return nil
    end

    local devOpenedByMe = false
    local function setDevConsole(on)
      local ok = pcall(function()
        game:GetService("StarterGui"):SetCore("DevConsoleVisible", on)
      end)
      if not ok then
        -- Dự phòng: giả lập phím F9 nếu SetCore bị chặn
        ok = pcall(function()
          local vim = game:GetService("VirtualInputManager")
          vim:SendKeyEvent(true, Enum.KeyCode.F9, false, game)
          task.wait(0.05)
          vim:SendKeyEvent(false, Enum.KeyCode.F9, false, game)
        end)
      end
      return ok
    end

    TabLog:CreateDropdown({
      Name = "Chế độ soi log",
      Options = { LBL_ALL, LBL_ERR, LBL_WARN, LBL_OK, LBL_DEV },
      CurrentOption = { LBL_ALL },
      Callback = function(opt)
        local pick = opt and opt[1]
        local lens = LENS_MAP.match(pick)
        if lens == "DEV" then
          -- Chỉ bật khi người dùng chủ động chọn mục này
          if setDevConsole(true) then
            devOpenedByMe = true
            Notify("Nhật Ký", _G.tR9("Đã mở bảng F9/F12 của Roblox."))
          else
            Notify("Nhật Ký", _G.tR9("Không mở được F9/F12 trên executor này."))
          end
          return
        end
        local key = (lens ~= "DEV") and lens or nil
        if key then
          if devOpenedByMe then
            devOpenedByMe = false
            if setDevConsole(false) then
              Notify("Nhật Ký", _G.tR9("Đã đóng bảng F9/F12 của Roblox."))
            end
          end
          if _G.fdc9d08687eec8de1 then _G.fdc9d08687eec8de1(key) end
        end
      end,
    })
    TabLog:CreateButton({ Name = "📎 Chép log vào bộ nhớ tạm", Callback = function()
      if _G.fbf53b00c4ea374d7 and _G.fbf53b00c4ea374d7() then Notify("Nhật Ký", "✅ Đã copy nhật ký vào clipboard!") else Notify("Nhật Ký", "❌ Executor không hỗ trợ copy.") end
    end })
    TabLog:CreateButton({ Name = "📥 Cất log ra file", Callback = function()
      if _G.a3f9b999afeefd20d then
        local ok, info = _G.a3f9b999afeefd20d()
        Notify("Nhật Ký", ok and ("✅ Đã lưu: " .. tostring(info)) or ("❌ Lỗi: " .. tostring(info)))
      end
    end })
    TabLog:CreateButton({ Name = "🧹 Quét sạch log", Callback = function()
      _G.HzConfirm("Quét sạch log?", "Xoá toàn bộ nhật ký trong khung log.", "Quét sạch", function()
        if _G.edf84e70ffcaf5b98 then _G.edf84e70ffcaf5b98() end
      end)
    end })
  end

  local TabSettings = Window:CreateTab("Tuỳ chỉnh", tonumber("11956055886"))
  TabSettings:CreateDivider({ text = "Hệ thống" })
  TabSettings:CreateSection("Hệ thống")

  TabSettings:CreateToggle({
    Name = "Màn trắng (AFK)",
    CurrentValue = false,
    Callback = function(Value)
      AFKFrame.BackgroundColor3 = Color3.new(1, 1, 1)
      AFKFrame.Visible = Value
    end,
  })

  TabSettings:CreateToggle({
    Name = "Màn đen (AFK)",
    CurrentValue = false,
    Callback = function(Value)
      AFKFrame.BackgroundColor3 = Color3.new(0, 0, 0)
      AFKFrame.Visible = Value
    end,
  })


  do
    -- 👁️ Ẩn tên người chơi (Mask): bật → che từ ký tự thứ 4; tắt → tên thật. Đổi là cập nhật ngay.
    local hMask = TabSettings:CreateToggle({
      Name = "Ẩn tên người chơi (Mask)",
      CurrentValue = (_G.HzPrivacyName ~= false),
      Flag = "HzPrivacyName",
      Save = true,
      Callback = function(v)
        _G.HzPrivacyName = (v == true)
        pcall(function() _G.HzPatchRayfieldName(GenWindow.screenGui) end)
      end,
    })

    -- 🎨 Giao diện Menu (Theme): 6 theme có sẵn của Rayfield Gen2, nhớ lại ở x8k2/framework.json (ui.theme)
    local THEMES = { "🪟 Default", "🔵 Cobalt", "🔥 Ember", "💜 Amethyst", "❄️ Frost", "🌸 Rose" } -- [V35]
    local THEMES_RAW = { "Default", "Cobalt", "Ember", "Amethyst", "Frost", "Rose" }
    local savedTheme = "Default"
    pcall(function()
      local s = _G.HzCfg and _G.HzCfg:Get("ui.theme", nil)
      if type(s) == "string" and table.find(THEMES_RAW, s) then savedTheme = s end
    end)
    _G.HzThemeCur = savedTheme
    TabSettings:CreateDropdown({
      Name = "Giao diện Menu (Theme)",
      Options = THEMES,
      CurrentOption = { THEMES[table.find(THEMES_RAW, savedTheme) or 1] }, -- [V35] hiển thị bản có emoji
      MultipleOptions = false,
      Callback = function(sel)
        local v = sel and sel[1]
        local idx = type(v) == "string" and (table.find(THEMES, v) or table.find(THEMES_RAW, v)) or nil
        if not idx then return end
        local raw = THEMES_RAW[idx] -- [V35] map ngược về tên raw
        if raw == _G.HzThemeCur then return end -- không đổi → bỏ qua
        _G.HzApplyTheme(raw, true)
        Notify("🎨 Theme", HzUiS("🎨 Đã đổi giao diện: ") .. raw)
      end,
    })
    TabSettings:CreateLabel("Default: mặc định (kính) · Cobalt: xanh đậm · Ember: cam cháy · Amethyst: tím · Frost: băng giá · Rose: hồng")

    -- 🛡️ Anti-AFK: di chuyển nhân vật nhẹ (Humanoid:Move) ngẫu nhiên 60–120 giây (xem _G.HzAntiAFK). MẶC ĐỊNH TẮT, không lưu trạng thái bật
    local hAFK = TabSettings:CreateToggle({
      Name = "Anti-AFK",
      CurrentValue = false,
      Flag = "HzAntiAFK",
      Save = false,
      Callback = function(v) _G.HzAntiAFK(v == true) end,
    })

    -- 🔄 Tự động vào lại khi bị đá: nghe bảng lỗi Disconnect/Kick rồi Teleport lại sau 10–20 giây ngẫu nhiên, tối đa 3 lần (xem _G.HzAutoRejoin). MẶC ĐỊNH BẬT
    local hRej = TabSettings:CreateToggle({
      Name = "Tự động vào lại khi bị đá",
      CurrentValue = true,
      Flag = "HzAutoRejoin",
      Save = false,
      Callback = function(v) _G.HzAutoRejoin(v == true) end,
    })

    -- Cấu hình đã lưu có thể được nạp sau lúc tạo phần tử → đồng bộ lại trạng thái từ công tắc sau 1.5 giây
    local myExec = currentExecute
    task.delay(1.5, function()
      if myExec ~= _G.d8e1181c0775aa002 then return end
      pcall(function()
        local function bool(h)
          if type(h) == "table" and type(h.value) == "boolean" then return h.value end
          return nil
        end
        local m = bool(hMask)
        if m ~= nil and m ~= (_G.HzPrivacyName ~= false) then
          _G.HzPrivacyName = m
          _G.HzPatchRayfieldName(GenWindow.screenGui)
        end
        local a = bool(hAFK)
        if a ~= nil and a ~= (_G.HzAntiAFKOn == true) then _G.HzAntiAFK(a) end
        local r = bool(hRej)
        if r == nil then r = true end
        if r ~= nil and r ~= (_G.HzAutoRejoinOn == true) then _G.HzAutoRejoin(r) end
      end)
    end)
  end

    -- Toggle bật tắt Khung Log riêng ở phần Cài đặt (Hoặc Tab Log)
  TabSettings:CreateToggle({
    Name = "🪟 Khung log nổi",
    CurrentValue = false,
    Callback = function(Value)
      if _G.b36db0b957e59dff2 then
        _G.b36db0b957e59dff2(Value)

        -- Thêm code hiện nhật ký khi bật/tắt
        if Value then
          if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Mini log: đang hiện", "SUCCESS") end
        else
          if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Mini log: đã ẩn", "WARN") end
        end
      end
    end,
  })

  TabSettings:CreateDivider({ text = "Phím tắt" })
  TabSettings:CreateSection("Phím tắt")
  do
    local function syncKey(handle, slot)
      pcall(function()
        local kc = _G.HzKeyOf(handle and handle.value)
        if kc then _G[slot] = kc end
      end)
    end
    local kbMenu = TabSettings:CreateKeybind({
      Name = "👁 Ẩn/hiện menu",
      Description = "Mặc định: RightShift",
      Value = _G.HzToggleKey,
      Flag = "HzKeyToggleMenu",
      Save = true,
      Callback = function() end, -- việc ẩn/hiện do bộ nghe phím ở trên xử lý (một nguồn duy nhất, không bị toggle đôi)
      OnChanged = function(k)
        local kc = _G.HzKeyOf(k)
        if kc then _G.HzToggleKey = kc end
      end,
    })
    local kbMusic = TabSettings:CreateKeybind({
      Name = "🎵 Bật/tắt nhạc",
      Description = "Mặc định: M — chỉ có tác dụng khi đang có bài phát",
      Value = _G.HzMusicKey,
      Flag = "HzKeyToggleMusic",
      Save = true,
      Callback = function() end,
      OnChanged = function(k)
        local kc = _G.HzKeyOf(k)
        if kc then _G.HzMusicKey = kc end
      end,
    })
    syncKey(kbMenu, "HzToggleKey")
    syncKey(kbMusic, "HzMusicKey")
    task.delay(1.5, function() -- cấu hình đã lưu có thể được nạp sau lúc tạo phần tử
      syncKey(kbMenu, "HzToggleKey")
      syncKey(kbMusic, "HzMusicKey")
    end)
  end

  TabSettings:CreateDivider({ text = "Tự động chạy" })
  TabSettings:CreateSection("Tự động chạy")
  do
    local A = _G.HzAutoload
    local hAuto = TabSettings:CreateToggle({
      Name = "☄️ Bật Auto-run khi vào game",
      CurrentValue = true,
      Flag = "HzAutoloadOn",
      Save = true,
      Callback = function(v) _G.HzAutoloadOn = (v == true) end,
    })
    local function summary()
      local n = A.count()
      if n == 0 then return HzUiS("☄️ Chưa có script Auto-run nào.") end
      return HzUiS("☄️ Đang Auto-run: ") .. n .. " — " .. table.concat(A.names(), ", ")
    end
    local PinLabel = TabSettings:CreateLabel(summary())

    -- Dropdown danh sách script đang Auto-run (nhãn "1. Tên" → link)
    local labelToUrl, optList, selLabel = {}, {}, nil
    local function build()
      labelToUrl, optList, selLabel = {}, {}, nil
      local list = A.list or A.load()
      for i, e in ipairs(list) do
        local lb = string.format("%d. %s", i, e.name)
        labelToUrl[lb] = e.url
        optList[#optList + 1] = lb
      end
      if #optList == 0 then optList = { HzUiS("— Chưa có script Auto-run —") } end
      if #list == 1 then selLabel = optList[1] end -- chỉ có 1 script thì mặc định chọn luôn
    end
    build()
    local PinDrop = TabSettings:CreateDropdown({
      Name = "☄️ Script đang Auto-run",
      Options = optList,
      CurrentOption = { optList[1] },
      MultipleOptions = false,
      Callback = function(sel)
        local v = sel and sel[1]
        selLabel = (type(v) == "string" and labelToUrl[v]) and v or nil
      end,
    })
    if labelToUrl[optList[1]] then selLabel = optList[1] end -- ô hiển thị sẵn mục đầu tiên

    TabSettings:CreateButton({
      Name = "Tắt Auto-run script đang chọn",
      Callback = function()
        local url = selLabel and labelToUrl[selLabel] or nil
        if not url then Notify("☄️ Auto-run", "Chưa chọn script nào!") return end
        local shown = (tostring(selLabel):gsub("^%d+%.%s*", ""))
        if A.remove(url) then -- A.remove gọi A.onChange → tự cập nhật nhãn + dropdown + nút ở Kho script
          Notify("☄️ Auto-run", HzUiS("☄️ Đã tắt Auto-run: ") .. shown)
        end
      end,
    })
    TabSettings:CreateButton({
      Name = "Bỏ ghim tất cả",
      Callback = function()
        _G.HzConfirm("Bỏ ghim tất cả?", "Xoá toàn bộ script khỏi danh sách Auto-run. Script trong Kho không bị xoá.", "Bỏ ghim", function()
          A.clear()
          Notify("☄️ Auto-run", "Đã bỏ ghim tất cả.")
        end)
      end,
    })
    TabSettings:CreateButton({
      Name = "Chạy Auto-run ngay",
      Callback = function()
        if A.count() == 0 then Notify("☄️ Auto-run", "Chưa có script Auto-run nào.") return end
        local n = A.runAll(_G.d8e1181c0775aa002)
        if n == 0 then
          Notify("☄️ Auto-run", "Auto-run đang tắt hoặc ở chế độ chỉ copy.")
        else
          Notify("☄️ Auto-run", string.format(_G.tR9("⭐ Đang tự chạy %d script đã ghim..."), n))
        end
      end,
    })

    -- Mỗi khi danh sách thay đổi (từ Kho script hoặc từ đây) → cập nhật lại toàn bộ UI liên quan
    A.onChange = function()
      pcall(function() PinLabel:Set(summary()) end)
      pcall(function()
        build()
        PinDrop:Refresh(optList, true)
      end)
      if _G.HzVaultPinRefresh then pcall(_G.HzVaultPinRefresh) end
      if _G.HzVaultUpdateDetail then pcall(_G.HzVaultUpdateDetail) end
    end

    -- Cấu hình đã lưu có thể được nạp sau lúc tạo phần tử → đồng bộ _G.HzAutoloadOn từ công tắc (trước lúc tự chạy lúc khởi động 2.5 giây)
    local myExec = currentExecute
    task.delay(1.5, function()
      if myExec ~= _G.d8e1181c0775aa002 then return end
      pcall(function()
        if type(hAuto) == "table" and type(hAuto.value) == "boolean" then _G.HzAutoloadOn = hAuto.value end
      end)
    end)
  end

  TabSettings:CreateSection("Giữ phiên script")
  do
    local R = _G.HzAutoRestore
    local function summary()
      local n = R.count()
      if n == 0 then return _G.tR9("Chưa giữ script nào. Bấm Chạy một script trong danh sách để được ghi nhận.") end
      return string.format(_G.tR9("Đang giữ %d script: "), n) .. table.concat(R.names(), ", ")
    end
    local SumLabel = TabSettings:CreateLabel(summary())

    _G.HzHubReloadEl = TabSettings:CreateToggle({
      Name = "Tự nạp lại hub khi đổi server",
      CurrentValue = (_G.HzAutoHubReload ~= false),
      Flag = "HzAutoHubReload",
      Save = true,
      Callback = function(v)
        _G.HzAutoHubReload = (v == true)
        pcall(R.setReload, v == true)
      end,
    })
    TabSettings:CreateLabel("Khi bật, HiulzHub tự chạy lại ở server mới mỗi khi bạn đổi server, vào lại hoặc bị kick (cần executor hỗ trợ queue_on_teleport). Tắt nếu hub của bạn đã tự chạy bằng autoexec. Mặc định bật.")

    local hSwitch = TabSettings:CreateToggle({
      Name = "Hỏi chạy lại khi đổi server",
      CurrentValue = (_G.HzAutoRestoreScripts == true),
      Flag = "HzAutoRestoreScripts",
      Save = true,
      Callback = function(v)
        _G.HzAutoRestoreScripts = (v == true)
        pcall(R.setEnabled, v == true)
      end,
    })
    TabSettings:CreateLabel("Khi bật, các script bạn đã bấm Chạy sẽ được hỏi để chạy lại khi bạn vào server mới hoặc vào lại. Mặc định tắt.")

    local hKick = TabSettings:CreateToggle({
      Name = "Chạy lại ngay khi bị kick",
      CurrentValue = (_G.HzAutoRestoreKick == true),
      Flag = "HzAutoRestoreKick",
      Save = true,
      Callback = function(v)
        _G.HzAutoRestoreKick = (v == true)
        pcall(R.setKick, v == true)
      end,
    })
    TabSettings:CreateLabel("Khi bị kick hoặc mất kết nối, script đã giữ (và hub nếu có đặt nguồn bên dưới) sẽ tự chạy lại khi bạn vào server mới, không cần hỏi. Dùng cùng Tự động vào lại khi bị đá để chạy hoàn toàn tự động. Mặc định tắt.")
    TabSettings:CreateInput({
      Name = "Link hoặc file hub",
      PlaceholderText = "https://... hoặc tên file .lua",
      CurrentValue = R.getHubSource() or "",
      Callback = function(Text)
        if (Text or "") == (R.getHubSource() or "") then return end -- bỏ qua lần gọi lúc nạp giá trị ban đầu
        local ok, how = R.setHubSource(Text)
        if ok then
          Notify("Giữ phiên script", how == "cleared" and "Đã xoá nguồn hub." or "Đã lưu nguồn hub.")
        else
          Notify("Giữ phiên script", "Nguồn hub không hợp lệ. Dùng link https hoặc tên file trong workspace.")
        end
      end,
    })
    TabSettings:CreateLabel("Dán link tải hub (https) hoặc tên file hub trong thư mục workspace của executor, rồi Enter. Hub được nạp lại từ nguồn này ở server mới. Để trống = dùng link mặc định của HiulzHub.")

    TabSettings:CreateButton({
      Name = "Xem danh sách đang giữ",
      Callback = function() Notify("Giữ phiên script", summary()) end,
    })
    TabSettings:CreateButton({
      Name = "Xoá danh sách đang giữ",
      Callback = function()
        _G.HzConfirm("Xoá danh sách giữ?", "Các script sẽ không được chạy lại nữa. Script trong Kho và Auto-run không bị xoá.", "Xoá", function()
          R.clear()
          Notify("Giữ phiên script", "Đã xoá danh sách giữ phiên.")
        end)
      end,
    })

    -- Mỗi khi danh sách đổi (bấm Chạy ở bất kỳ tab nào, hoặc xoá) → cập nhật nhãn + chi tiết ở Kho script
    R.onChange = function()
      pcall(function() SumLabel:Set(summary()) end)
      if _G.HzVaultUpdateDetail then pcall(_G.HzVaultUpdateDetail) end
    end

    -- Cấu hình đã lưu có thể được nạp sau lúc tạo phần tử → đồng bộ lại từ công tắc sau 1.5 giây
    local myExec = currentExecute
    task.delay(1.5, function()
      if myExec ~= _G.d8e1181c0775aa002 then return end
      pcall(function()
        local hr = _G.HzHubReloadEl
        if type(hr) == "table" and type(hr.value) == "boolean" and hr.value ~= (_G.HzAutoHubReload ~= false) then
          R.setReload(hr.value)
        end
        if type(hSwitch) == "table" and type(hSwitch.value) == "boolean" and hSwitch.value ~= (_G.HzAutoRestoreScripts == true) then
          R.setEnabled(hSwitch.value)
        end
        if type(hKick) == "table" and type(hKick.value) == "boolean" and hKick.value ~= (_G.HzAutoRestoreKick == true) then
          R.setKick(hKick.value)
        end
      end)
    end)
  end

  TabSettings:CreateDivider({ text = "Ngôn ngữ" })
  TabSettings:CreateSection("Ngôn ngữ / Language")
  do
    local OPT_AUTO = "Auto (theo quốc gia)" -- [FIX LANG]
    local OPT_VI = "Tiếng Việt"
    local OPT_EN = "English"
    local OPT_PT = "Português (Brasil)"
    local curMode = (_G.lM11 and _G.lM11()) or "auto"
    local info = (_G.lI13 and _G.lI13()) or { code = "??" }
    local curLang = (_G.lG10 and _G.lG10()) or "vi"
    TabSettings:CreateLabel("Khu vực / Region: " .. tostring(info.code) .. " → " .. ((curLang == "vi" and OPT_VI) or (curLang == "pt" and OPT_PT) or OPT_EN))
    local initial = (curMode == "vi" and OPT_VI) or (curMode == "en" and OPT_EN) or (curMode == "pt" and OPT_PT) or OPT_AUTO
    TabSettings:CreateDropdown({
      Name = "Ngôn ngữ / Language",
      Options = { OPT_AUTO, OPT_VI, OPT_EN, OPT_PT },
      CurrentOption = { initial },
      MultipleOptions = false,
      Callback = function(sel)
        local v = sel and sel[1]
        local newMode = (v == OPT_VI and "vi") or (v == OPT_EN and "en") or (v == OPT_PT and "pt") or (v == OPT_AUTO and "auto") or nil
        local saved = (_G.lM11 and _G.lM11()) or "auto"
        if not newMode or newMode == saved or not _G.sL12 then return end
        _G.sL12(newMode) -- lưu + đổi ngôn ngữ ngay (Window:SetLocale khi Gen2 localization bật)
        pcall(function()
          local nowLang = (_G.lG10 and _G.lG10()) or "vi"
          if _G.gL22 then
            if nowLang == "en" then
              Notify("Language", "✅ " .. tostring(v) .. " — Applied instantly to the menu. (Custom HUDs may need a re-execute.)")
            elseif nowLang == "pt" then
              Notify("Idioma", "✅ " .. tostring(v) .. " — Aplicado na hora ao menu. (HUDs personalizados podem precisar de novo execute.)")
            else
              Notify("Ngôn ngữ", "✅ " .. tostring(v) .. " — Đã áp dụng ngay cho menu. (HUD tự vẽ có thể cần execute lại.)")
            end
          else
            if nowLang == "en" then
              Notify("Language", "✅ " .. tostring(v) .. " — Re-execute the script to apply it to the whole menu.")
            elseif nowLang == "pt" then
              Notify("Idioma", "✅ " .. tostring(v) .. " — Execute o script de novo para aplicar a todo o menu.")
            else
              Notify("Ngôn ngữ", "✅ " .. tostring(v) .. " — Chạy lại script để áp dụng cho toàn bộ menu.")
            end
          end
        end)
      end,
    })
  end

  HiulzFW.UI.AddModuleToggles(TabSettings)

  TabSettings:CreateDivider({ text = "Menu" })
  TabSettings:CreateSection("Menu")

  -- Toàn bộ quy trình đóng/dọn dẹp (giữ nguyên code gốc), được gọi sau khi người dùng xác nhận
  -- (dùng _G thay vì local để không tăng số biến local của hàm StartRayfield — giới hạn 200)
  _G.cE23 = function()
      local function safeCall(fn, ...) pcall(fn, ...) end
      pcall(function() HiulzFW.Shutdown() end)

      pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
          Title = "HiulzHub",
          Text = _G.tR9("Đang tắt menu và dọn dẹp..."),
          Duration = 3
        })
      end)

      _G.HzMusicRuntime = nil
      safeCall(function()
        if CurrentMusic then
          if type(CurrentMusic.Stop) == "function" then pcall(CurrentMusic.Stop, CurrentMusic) end
          if type(CurrentMusic.Destroy) == "function" then pcall(CurrentMusic.Destroy, CurrentMusic) end
          CurrentMusic = nil
        end
        local ss = game:GetService("SoundService")
        for _, s in ipairs(ss:GetChildren()) do
          if s:IsA("Sound") and HzOwn(tostring(s.Name)) then
            pcall(function() if s.Playing then s:Stop() end end)
            pcall(function() if s.Destroy then s:Destroy() end end)
          end
        end
      end)

      safeCall(function()
        _G.b655ac11a998f805f = false
        _G.lM4 = false
        _G.lG5 = false
        pcall(function() getgenv().LowGpu = false end)
      end)

      safeCall(function()
        if AFKFrame and typeof(AFKFrame) == "Instance" then
          pcall(function() AFKFrame.Visible = false end)
        end
        if AFKGui and typeof(AFKGui) == "Instance" then
          pcall(function() AFKGui:Destroy() end)
          AFKGui = nil
        end
        if LoadingGui and typeof(LoadingGui) == "Instance" then
          pcall(function() LoadingGui:Destroy() end)
          LoadingGui = nil
        end
        local function cleanGuiParent(parent)
          if not parent or not parent.GetDescendants then return end
          for _, inst in ipairs(parent:GetDescendants()) do
            local ok, name = pcall(function() return tostring(inst.Name) end)
            if ok and name and HzOwn(name) then
              pcall(function() if inst.Destroy then inst:Destroy() end end)
            end
          end
        end
        pcall(function() cleanGuiParent(game:GetService("CoreGui")) end)
        local pl = game:GetService("Players").LocalPlayer
        if pl then pcall(function() cleanGuiParent(pl:FindFirstChild("PlayerGui")) end) end
      end)

      safeCall(function()
        local Lighting = game:GetService("Lighting")
        if _G.HzGfxTouched == true then -- [PERF] chỉ khôi phục nếu người dùng đã bấm "Giảm đồ họa"
          if _G.originalBrightness ~= nil then pcall(function() Lighting.Brightness = _G.originalBrightness end) end
          if _G.originalClockTime ~= nil then pcall(function() Lighting.ClockTime = _G.originalClockTime end) end
          if _G.originalFogEnd ~= nil then pcall(function() Lighting.FogEnd = _G.originalFogEnd end) end
          if _G.originalGlobalShadows ~= nil then pcall(function() Lighting.GlobalShadows = _G.originalGlobalShadows end) end
        end
      end)

      -- [PERF] ĐÃ XOÁ: khôi phục WalkSpeed/JumpPower/JumpHeight/HipHeight của LocalPlayer.
      -- Hub không hề đổi các giá trị này, ghi lại giá trị cũ chỉ làm đè lên giá trị game đang dùng.

      safeCall(function()
        if _G.rW15 and type(_G.rW15.Unload) == "function" then pcall(function() _G.rW15:Unload() end) end
        _G.rW15 = nil
        if _G.rF14 then
          local rf = _G.rF14
          if typeof(rf) == "Instance" then
            pcall(function() rf:Destroy() end)
          else
            if type(rf.Unload) == "function" then pcall(rf.Unload, rf) end
            if type(rf.Close) == "function" then pcall(rf.Close, rf) end
            if type(rf.Destroy) == "function" then pcall(rf.Destroy, rf) end
          end
          _G.rF14 = nil
        end
      end)

      safeCall(function()
        _G.b655ac11a998f805f = false
        if type(_G.dH6) == "function" then
          pcall(_G.dH6)
        else
          local hudName = HzN.hud
          local parent = GetSafeGui()
          if parent then
            local existing = parent:FindFirstChild(hudName)
            if existing and typeof(existing) == "Instance" then pcall(function() existing:Destroy() end) end
          end
          local coreExisting = game:GetService("CoreGui"):FindFirstChild(hudName)
          if coreExisting and typeof(coreExisting) == "Instance" then pcall(function() coreExisting:Destroy() end) end
        end
      end)

      safeCall(function()
        if _G.HzGfxTouched == true and type(_G.originalQuality) == "number" then -- [PERF] chỉ khi người dùng đã giảm đồ họa
          pcall(function() if settings and settings().Rendering then settings().Rendering.QualityLevel = _G.originalQuality end end)
        end
        _G.lM4 = false
        _G.lG5 = false
        pcall(function() getgenv().LowGpu = false end)
      end)

      safeCall(function()
        local CAS = game:GetService("ContextActionService")
        local toUnbind = {"ToggleHUD","SomeHotkeyAction","ToggleAFK","ToggleMusic","ToggleStatusHUD","AFK_Toggle","Music_Toggle"}
        for _, name in ipairs(toUnbind) do
          pcall(function() CAS:UnbindAction(name) end)
        end
      end)

      safeCall(function()
        local connKeys = {"_renderConn","_heartbeatConn","_steppedConn","_rendersteppedConn","_rsConn","_hbConn","_runConn","_loopConn"}
        for _, k in ipairs(connKeys) do
          local c = _G[k]
          if c then
            pcall(function() if c.Connected then c:Disconnect() end end)
            _G[k] = nil
          end
        end
        if type(_G._connections) == "table" then
          for k, v in pairs(_G._connections) do
            local c = (typeof(k) == "RBXScriptConnection") and k or v -- [V35]
            pcall(function() if c and c.Connected then c:Disconnect() end end)
          end
          _G._connections = nil
        end
      end)

      safeCall(function()
        local commonKeys = {"_functions","Functions","CloseFunctions","_listeners","_threads","_tasks","_loops","Connections","_modules","_widgets","_coroutines","_threads"}
        for _, key in ipairs(commonKeys) do
          local v = _G[key]
          if type(v) == "table" then
            for _, obj in pairs(v) do
              pcall(function()
                if type(obj) == "function" then pcall(obj) end
                if type(obj) == "table" then
                  if type(obj.Destroy) == "function" then pcall(obj.Destroy, obj) end
                  if type(obj.Close) == "function" then pcall(obj.Close, obj) end
                  if type(obj.Unload) == "function" then pcall(obj.Unload, obj) end
                  if type(obj.Disconnect) == "function" then pcall(obj.Disconnect, obj) end
                  if type(obj.disconnect) == "function" then pcall(obj.disconnect, obj) end
                end
              end)
            end
          elseif type(v) == "function" then
            pcall(v)
          elseif typeof and typeof(v) == "Instance" then
            pcall(function() v:Destroy() end)
          end
          _G[key] = nil
        end

        for gk, gv in pairs(_G) do
          pcall(function()
            if type(gv) == "table" then
              if type(gv.Destroy) == "function" then pcall(gv.Destroy, gv) end
              if type(gv.Close) == "function" then pcall(gv.Close, gv) end
              if type(gv.Unload) == "function" then pcall(gv.Unload, gv) end
              if type(gv.Disconnect) == "function" then pcall(gv.Disconnect, gv) end
              if type(gv.disconnect) == "function" then pcall(gv.disconnect, gv) end
            end
            if typeof and typeof(gv) == "Instance" then
              pcall(function() if gv and gv.Destroy then gv:Destroy() end end)
            end
          end)
        end
      end)

      safeCall(function()
        local function destroyIfPrefixed(parent)
          if not parent or not parent.GetDescendants then return end
          for _, inst in ipairs(parent:GetDescendants()) do
            local ok, name = pcall(function() return tostring(inst.Name) end)
            if ok and name and HzOwn(name) then
              pcall(function() if inst.Destroy then inst:Destroy() end end)
            end
          end
        end
        pcall(function()
          for _, e in ipairs(game:GetService("Lighting"):GetChildren()) do
            if e:IsA("BlurEffect") and HzOwn(e.Name) then e:Destroy() end
          end
        end)
        pcall(function() destroyIfPrefixed(game:GetService("CoreGui")) end)
        local pl = game:GetService("Players").LocalPlayer
        if pl then pcall(function() destroyIfPrefixed(pl:FindFirstChild("PlayerGui")) end) end
      end)

      safeCall(function()
        local clear = {"_AUTO_LOAD","_LOADER","_MUSIC_ID","_music","_tempGui","lG5","LoadUi","sT1"}
        for _, k in ipairs(clear) do _G[k] = nil end
      end)

      safeCall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
          Title = "✅",
          Text = _G.tR9("Đã đóng Menu và tắt tất cả chức năng!"),
          Duration = 5
        })
      end)
  end

  -- [POPUP GEN2] Hộp thoại xác nhận trước khi đóng toàn bộ script
  TabSettings:CreateButton({
    Name = "Đóng menu",
    Callback = function()
      local win = _G.rW15
      local T = _G.gL22 and function(x) return x end or _G.tR9 -- Gen2 localization tự dịch; chế độ cũ dịch tay
      local shown = false
      if win and type(win.Popup) == "function" then
        shown = pcall(function()
          win:Popup({
            title = T("Đóng toàn bộ script?"),
            content = T("Tắt mọi chức năng, dừng nhạc, xoá HUD và gỡ menu. Bạn cần execute lại script để dùng tiếp."),
            options = {
              { text = T("Hủy"), style = "neutral" },
              {
                text = T("Đóng toàn bộ"),
                style = "danger",
                -- callback chạy TRƯỚC khi popup đóng -> trì hoãn để popup đóng xong rồi mới gỡ menu
                callback = function() task.defer(_G.cE23) end,
              },
            },
            dismissable = true,
          })
        end)
      end
      -- Thư viện không có Popup -> đóng thẳng như v18
      if not shown then _G.cE23() end
    end
  })

  HiulzFW.Start()

  if _G.HzPerf then _G.HzPerf("Dựng xong menu") end

  -- Trễ 2.5s để cấu hình đã lưu (công tắc ⭐ Tự chạy…) kịp nạp; bỏ qua nếu có lần execute mới hơn hoặc đang ở chế độ chỉ copy.
  do
    local myExec = currentExecute
    task.delay(_G.HzPerfPick(2.5, 2.5, 5), function() -- [PERF] LOW 5s
      if myExec ~= _G.d8e1181c0775aa002 then return end
      pcall(function()
        local A = _G.HzAutoload
        if not A or _G.HzAutoloadOn == false or _G.f8eefa956e6130f83 then return end
        local list = A.load()
        if #list == 0 then return end
        SafeNotify("⭐ Autoload", string.format(_G.tR9("⭐ Đang tự chạy %d script đã ghim..."), #list))
        if _G.aa3542001e064bc52 then _G.aa3542001e064bc52("Autoload: chạy " .. #list .. " script đã ghim", "INFO") end
        A.runAll(myExec)
      end)
    end)
  end

  task.delay(_G.HzPerfPick(3.5, 3.5, 6), function() -- [PERF] LOW 6s
    if currentExecute ~= _G.d8e1181c0775aa002 then return end
    pcall(function()
      local A = _G.HzAutoRestore
      if not A then return end
      A.watch(A.wantWatch()) -- bật/tắt bộ nghe kick theo công tắc đã lưu
      A.watchTeleport(_G.HzAutoHubReload ~= false)
      if isReExecution then return end -- không hỏi khi re-execute
      if _G.f8eefa956e6130f83 == true then return end -- chế độ chỉ copy
      if _G.HzRestorePromptedThisSession then return end
      if A.bootDone() then -- mã hẹn giờ (queue_on_teleport) đã tự chạy lại rồi → không chạy trùng
        _G.HzRestorePromptedThisSession = true
        A.clearPending()
        if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "AutoRestore: bỏ qua (đã chạy lại bằng mã hẹn giờ)", "INFO") end
        return
      end
      -- 1) Vừa bị kick/mất kết nối ở đúng game này (trong 15 phút) và công tắc kick đang bật → chạy lại luôn, không hỏi, giữ danh sách
      if _G.HzAutoRestoreKick == true and A.pendingFresh() and A.count() > 0 then
        _G.HzRestorePromptedThisSession = true
        A.clearPending()
        A.runAll(_G.d8e1181c0775aa002, true)
        return
      end
      -- 2) Đổi server bình thường: hỏi trước khi chạy lại
      if _G.HzAutoRestoreScripts ~= true then
        if _G.aa3542001e064bc52 then pcall(_G.aa3542001e064bc52, "AutoRestore: bỏ qua (công tắc tắt)", "INFO") end
        return
      end
      _G.HzRestorePromptedThisSession = true
      if A.count() == 0 then return end
      if A.sameJob() then return end -- chỉ hỏi khi JobId khác lần trước
      A.prompt(function() A.runAll(_G.d8e1181c0775aa002) end, function() A.clear() end)
    end)
  end)

  do
    local myExec, CUR = currentExecute, 41 -- CUR = số phiên bản của file này
    task.spawn(function()
      pcall(function()
        local body, done = nil, false
        task.spawn(function()
          local ok, r = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/hidescript/x8k2-db/main/version.json", true) end)
          if ok and type(r) == "string" then body = r end
          done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < 2 do task.wait(0.1) end
        if not body or myExec ~= _G.d8e1181c0775aa002 then return end
        local d = game:GetService("HttpService"):JSONDecode(body)
        local v = type(d) == "table" and tonumber(d.version)
        if v and v > CUR then
          Notify("🆕 Update", string.format(_G.tR9("🆕 Có bản V%s — liên hệ Discord để lấy"), tostring(d.version)))
        end
      end)
    end)
  end

end -- kết thúc StartRayfield

----------------------------------------------------------------
-- CHẠY LOADING TRƯỚC, RAYFIELD SAU (TỐI ƯU HÓA RE-EXECUTE)
----------------------------------------------------------------
local function RunLoading()
  if isReExecution then
    if LoadingGui then LoadingGui:Destroy() end
    StartRayfield()
    return
  end

  if _G.HzLiteLoad == true then
    SetLoadProgress(1, "✨ Sẵn sàng!")
    task.wait(0.15)
    if currentExecute ~= _G.d8e1181c0775aa002 then
      if CloseLoading then pcall(CloseLoading) end -- [FIX RACE]
      return
    end
    CloseLoading()
    StartRayfield()
    return
  end

  local steps = {
    {0.12, "Kiểm tra bảo mật..."},
    {0.30, "Tải tài nguyên..."},
    {0.50, "Nạp danh sách script..."},
    {0.70, "Đồng bộ giao diện..."},
    {0.90, "Hoàn tất..."},
    {1.0, "✨ Sẵn sàng!"}
  }
  local function waitOrSkip(sec)
    local t0 = os.clock()
    while os.clock() - t0 < sec do
      if LoadingGui and LoadingGui:GetAttribute("Skip") then return true end
      task.wait(0.05)
    end
    return false
  end

  local skipped = false
  for _, s in ipairs(steps) do
    SetLoadProgress(s[1], s[2])
    if waitOrSkip(_G.HzPerfPick(0.6, 0.4, 0.3)) then -- [PERF]
      skipped = true
      break
    end
  end

  if skipped then
    SetLoadProgress(1, "✨ Sẵn sàng!")
    task.wait(_G.HzPerfPick(0.25, 0.15, 0.1)) -- [PERF]
  else
    task.wait(_G.HzPerfPick(0.4, 0.25, 0.15)) -- [PERF]
  end

  if currentExecute ~= _G.d8e1181c0775aa002 then
    if CloseLoading then pcall(CloseLoading) end -- [FIX RACE]
    return
  end

  CloseLoading()
  StartRayfield()
end

RunLoading()

-- [BẢN VÁ LỖI KẸT NÚT TSB TRÊN ĐIỆN THOẠI]
task.spawn(function()
  local Players = game:GetService("Players")
  local UserInputService = game:GetService("UserInputService")
  local CoreGui = game:GetService("CoreGui")

  local function FixMobileTouchBlocks(char)
    if _G.HzIsDesktop == true then return end
    if char then pcall(function() char:WaitForChild("Humanoid", 5) end) end

    task.spawn(function()
      for i = 1, 5 do
        pcall(function()
          local player = Players.LocalPlayer
          if not player then return end

          pcall(function()
            if UserInputService.ModalEnabled then
              UserInputService.ModalEnabled = false
            end
          end)

          local playerGui = player:FindFirstChild("PlayerGui")
          if playerGui then
            local touchGui = playerGui:FindFirstChild("TouchGui")
            if touchGui and touchGui:FindFirstChild("TouchControlFrame") then
              touchGui.TouchControlFrame.Visible = true
            end
          end

          for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") and tostring(gui.Name) == HzN.loading then
              gui:Destroy()
            end
          end
        end)
        task.wait(0.5) -- [FIX] Kiểm tra nhanh chóng sau mỗi 0.5s
      end
    end)
  end

  local player = Players.LocalPlayer
  if player then
    if _G.tM16 then
      pcall(function() _G.tM16:Disconnect() end)
    end
    _G.tM16 = player.CharacterAdded:Connect(function(char)
      if char then FixMobileTouchBlocks(char) end -- [FIX] Bảo vệ truy cập char (Chặn lỗi F9)
    end)
    if player.Character then
      FixMobileTouchBlocks(player.Character)
    end
  end
end)

-- ==========================================
-- [HỆ THỐNG CẢNH BÁO ADMIN/MOD XÂM NHẬP]
-- ==========================================
task.spawn(function()
  local Players = game:GetService("Players")
  local TweenService = game:GetService("TweenService")
  local HttpService = game:GetService("HttpService")
  local CoreGui = game:GetService("CoreGui")

  local adminListUrl = "https://raw.githubusercontent.com/67HubDev/AntiAdmin/refs/heads/main/admin.json"
  local admins = {}

  -- chỉ fetch đồng bộ (có timeout) khi chưa có cache hoặc cache cũ hơn 24h.
  local CACHE_DIR, CACHE_FILE, TTL, FETCH_TIMEOUT = "x8k2", "x8k2/admin_cache.json", ((_G.HzConst or {}).adminCache or {}).ttl or (24 * 60 * 60), ((_G.HzConst or {}).adminCache or {}).fetchTimeout or 5 -- [V35]
  local hasFS = type(isfile) == "function" and type(readfile) == "function" and type(writefile) == "function"

  local function applyList(list)
    if type(list) ~= "table" then return end
    for k in pairs(admins) do admins[k] = nil end
    for _, v in ipairs(list) do
      admins[tostring(v):lower()] = true
    end
  end

  local function readCache() -- trả về list, tuổi cache (giây)
    if not hasFS then return nil end
    local list, age
    pcall(function()
      if isfile(CACHE_FILE) then
        local d = HttpService:JSONDecode(readfile(CACHE_FILE))
        if type(d) == "table" and type(d.list) == "table" and tonumber(d.ts) then
          list, age = d.list, os.time() - tonumber(d.ts)
        end
      end
    end)
    return list, age
  end

  local function writeCache(list)
    if not hasFS then return end
    pcall(function()
      if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(CACHE_DIR) then makefolder(CACHE_DIR) end
      writefile(CACHE_FILE, HttpService:JSONEncode({ ts = os.time(), list = list }))
    end)
  end

  -- HttpGet chạy ở thread riêng, chờ tối đa `timeout` giây (mạng chậm không chặn vô hạn)
  local function fetchList(timeout)
    local done, list = false, nil
    task.spawn(function()
      local ok, raw = pcall(function() return game:HttpGet(adminListUrl, true) end)
      if ok and type(raw) == "string" and raw ~= "" then
        local ok2, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok2 and type(decoded) == "table" then list = decoded end
      end
      done = true
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < timeout do task.wait(0.05) end
    return list
  end

  pcall(function()
    local cached, age = readCache()
    if _G.HzPerfLvl == "low" then
      -- [PERF] LOW: chỉ dùng cache lúc khởi động, KHÔNG fetch mới. Cache thiếu/quá hạn → làm mới nền muộn (không chặn)
      if cached then applyList(cached) end
      if not (cached and age and age >= 0 and age < TTL) then
        task.delay(cached and 120 or 45, function()
          local fresh = fetchList(FETCH_TIMEOUT)
          if fresh then applyList(fresh); writeCache(fresh) end
        end)
      end
    elseif cached and age and age >= 0 and age < TTL then
      applyList(cached)
      task.delay(8, function() -- làm mới nền, không chặn
        local fresh = fetchList(FETCH_TIMEOUT)
        if fresh then applyList(fresh); writeCache(fresh) end
      end)
    else
      local fresh = fetchList(FETCH_TIMEOUT)
      if fresh then
        applyList(fresh)
        writeCache(fresh)
      elseif cached then
        applyList(cached) -- mạng lỗi: dùng cache cũ còn hơn không có
      end
    end
  end)

  local backupAdmins = {
    ["Roblox"] = true,
    ["1"] = true
  }

  local function checkAdmin(player)
    local name = player.Name:lower()
    local id = tostring(player.UserId)
    if admins[name] or admins[id] or backupAdmins[name] or backupAdmins[id] then
      return true
    end
    return false
  end

  local function showWarning(playerName)
    pcall(function()
      local safeParent = CoreGui
      local lvl = _G.HzPerfLvl or "high" -- [PERF] HIGH: flashing + tween | MED: chỉ fade | LOW: text tĩnh 4s
      local isLow = (lvl == "low")

      local warningGui = Instance.new("ScreenGui")
      warningGui.Name = HzN.admin .. math.random(1000,9999)
      warningGui.IgnoreGuiInset = true
      warningGui.ResetOnSpawn = false -- [FIX] Chống mất UI khi chết
      warningGui.DisplayOrder = 999999
      warningGui.Parent = safeParent

      local warnFrame = Instance.new("Frame")
      warnFrame.Size = UDim2.new(1, 0, 0, 60)
      warnFrame.Position = UDim2.new(0, 0, 0.2, 0)
      warnFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
      warnFrame.BackgroundTransparency = isLow and 0.3 or 1 -- [PERF]
      warnFrame.BorderSizePixel = 0
      warnFrame.Parent = warningGui

      if not isLow then -- [PERF] LOW: không gradient
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
          ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 0, 0)),
          ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 0)),
          ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 0))
        })
        gradient.Parent = warnFrame
      end

      local warnText = Instance.new("TextLabel")
      warnText.Size = UDim2.new(1, -20, 1, 0)
      warnText.Position = UDim2.new(0, 10, 0, 0)
      warnText.BackgroundTransparency = 1
      warnText.Text = _G.tR9("⚠️ CẢNH BÁO: ADMIN/MOD [") .. string.upper(playerName) .. _G.tR9("] VỪA VÀO SERVER! ⚠️")
      warnText.TextColor3 = Color3.fromRGB(255, 255, 255)
      warnText.TextSize = 18
      warnText.Font = Enum.Font.GothamBlack
      warnText.TextTransparency = isLow and 0 or 1 -- [PERF]
      warnText.TextWrapped = true
      warnText.Parent = warnFrame

      if not isLow then -- [PERF] LOW: không tween
        local tweenIn = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        TweenService:Create(warnFrame, tweenIn, {BackgroundTransparency = 0.3}):Play()
        TweenService:Create(warnText, tweenIn, {TextTransparency = 0}):Play()
      end

      local isFlashing = (lvl == "high") -- [PERF] chỉ HIGH nhấp nháy
      task.spawn(function()
        while isFlashing and warnText.Parent do
          TweenService:Create(warnText, TweenInfo.new(0.4), {TextColor3 = Color3.fromRGB(255, 200, 200)}):Play()
          task.wait(0.4)
          TweenService:Create(warnText, TweenInfo.new(0.4), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
          task.wait(0.4)
        end
      end)

      task.delay(isLow and 4 or 6, function() -- [PERF] LOW 4s
        isFlashing = false
        if isLow then pcall(function() warningGui:Destroy() end) return end -- [PERF] LOW: tắt thẳng, không fade
        local fadeOut = TweenService:Create(warnFrame, TweenInfo.new(1), {BackgroundTransparency = 1})
        TweenService:Create(warnText, TweenInfo.new(1), {TextTransparency = 1}):Play()
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
          warningGui:Destroy()
        end)
      end)
    end)
  end

  for _, player in ipairs(Players:GetPlayers()) do
    if player ~= Players.LocalPlayer and checkAdmin(player) then
      showWarning(player.Name)
    end
  end

  Players.PlayerAdded:Connect(function(player)
    if checkAdmin(player) then
      showWarning(player.Name)
    end
  end)
end)
