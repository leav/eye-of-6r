#==============================================================================
# ■ Eye_of_6R
#------------------------------------------------------------------------------
# 　查看6R在线会员 :]
#   2008/8/2 1.0
#   2008/8/5 1.1
#     IP查看与马甲辨认
#==============================================================================

module Eye_of_6R
  #--------------------------------------------------------------------------
  # ● 常数
  #--------------------------------------------------------------------------
  OUTPUT_FILE = 'log.txt'
  OUTPUT_MODE = 'w'
  MEMBERS_FOLDER = 'Members'
  MEMBERS_FILE = 'members.rxdata'
  INQUIRY_FILE = 'ip_search.txt'
  MAJIA_OUTPUT_FILE = 'majia.txt'
  MAJIA_OUTPUT_MODE = 'w'
  VIEWING_RANKING = 20
  
  module_function
  #--------------------------------------------------------------------------
  # ● 循环运行
  #   period: 循环间隔秒数
  #--------------------------------------------------------------------------
  def loop_run(period = 900)
    loop{
      run
      period.times{
        Graphics.update
        Input.update
        if Input.press?(Input::B)
          return
        end
        sleep(1)
      }
    }
  end
  #--------------------------------------------------------------------------
  # ● 运行
  #--------------------------------------------------------------------------
  def run
    @file = File.open(OUTPUT_FILE, OUTPUT_MODE)
    begin
      ini_sprite
      write_header
      users = get_users
      save_members(users)
      write_member_activity(users)
      write_hot_topics(users)
      #print "完成！请打开#{OUTPUT_FILE}查看结果 :D"
    rescue
      #raise '获取失败，可能是网络连接出现问题或者柳大改了网页格式 :('
    ensure
      @file.close
    end
  end
  #--------------------------------------------------------------------------
  # ● 写入时间信息
  #--------------------------------------------------------------------------
  def write_header
    time = Time.now
    s = "\n╮(￣▽￣)╭ ╮(￣▽￣)╭ ╮(￣▽￣)╭ ╮(￣▽￣)╭ ╮(￣▽￣)╭ \n\n" +
    "#{time.year}年#{time.month}月#{time.mday}日 " + 
    "星期#{time.wday} " + 
    "#{time.hour}:#{time.min}:#{time.sec}\n\n"
    @file.write(EasyConv.u2s(s))
  end
  #--------------------------------------------------------------------------
  # ● 写入会员活动信息
  #--------------------------------------------------------------------------
  def write_member_activity(users)
    s = "在线会员活动情况：\n\n"
    members = []
    for user in users
      if user.member?
        members.push(user)
      end
    end
    for member in members.sort
      s += member.inspect + "\n"
    end
    s += "\n"
    @file.write(EasyConv.u2s(s))
  end
  #--------------------------------------------------------------------------
  # ● 写入即时论坛二十大
  #--------------------------------------------------------------------------
  def write_hot_topics(users)
    s = "即时论坛点击二十大：\n\n"
    topics = {}
    for user in users
      if topics[user.viewing] == nil
        topics[user.viewing] = 1
      else
        topics[user.viewing] += 1
      end
    end
    sorted_topics = topics.keys.sort{|a, b| topics[b] <=> topics[a]}
    for i in 0...sorted_topics.size
      break if i >= VIEWING_RANKING
      s += "#{sorted_topics[i]}   人气：#{topics[sorted_topics[i]]}\n"
    end
    s += "\n"
    @file.write(EasyConv.u2s(s))
  end
  #--------------------------------------------------------------------------
  # ● 获取在线用户
  #--------------------------------------------------------------------------
  def get_users
    users = []
    html = Get_Http_Info.get_html('http://bbs.66rpg.com/onlineUsers.asp?')
    pages = get_page_num(html)
    for i in 0...pages
      html = EasyConv.s2u(Get_Http_Info.get_html("http://bbs.66rpg.com/onlineUsers.asp?page=#{pages - i}"))
      users |= get_page_users(html)
      draw_progress(i + 1, pages)
   end
    return users
  end
  #--------------------------------------------------------------------------
  # ● 获取在线用户页面数量
  #--------------------------------------------------------------------------
  def get_page_num(html)
    html.slice(/\<a href\=\"onlineUsers\.asp\?page\=(\d*?)\&/m)
    return $1.to_i
  end
  #--------------------------------------------------------------------------
  # ● 获取当页在线用户
  #--------------------------------------------------------------------------
  def get_page_users(html)
    users = []
    while html.slice!(/\<tr.class\=\'rowbg[12].*?\<td\>(.*?)\<\/td\>.*?\<td\>(.*?)\<\/td\>.*?\<td\>(.*?)\<\/td\>.*?\<\/tr\>/m) != nil
      users.push(User_6R.new($1, $3, $2))
    end
    return users
  end
  #--------------------------------------------------------------------------
  # ● 储存用户
  #--------------------------------------------------------------------------
  def save_members(users)
    if FileTest.exist?(MEMBERS_FILE)
      members = load_data(MEMBERS_FILE)
    else
      members = []
    end
    for user in users
      next if not user.member?
      if members.include?(user)
        members[members.index(user)].add_ip(user.current_ip)
      else
        members.push(user)
      end
    end
    save_data(members, MEMBERS_FILE)
    return members
  end
  #--------------------------------------------------------------------------
  # ● 合并文件
  #    
  #--------------------------------------------------------------------------
  def merge_data
    if FileTest.exist?(MEMBERS_FILE)
      members = load_data(MEMBERS_FILE)
    else
      members = []
    end
    old_num_of_members = members.size
    Dir.chdir(MEMBERS_FOLDER)
    files = Dir.glob('*.rxdata')
    for file in files
      import_members = load_data(file)
      for user in import_members
        if members.include?(user)
          members[members.index(user)].add_ip(user.current_ip)
        else
          members.push(user)
        end
      end
    end
    Dir.chdir('..')
    save_data(members, MEMBERS_FILE)
    p "合并前数据库会员数量: #{old_num_of_members}，合并后: #{members.size}"
  end  
  #--------------------------------------------------------------------------
  # ● 打印马甲
  #--------------------------------------------------------------------------
  def print_majia(ip_difference = 0)
    members = load_data(MEMBERS_FILE)
    majias = find_majia(members, ip_difference)
    file = File.open(MAJIA_OUTPUT_FILE, MAJIA_OUTPUT_MODE)
    file2 = File.open(INQUIRY_FILE, "r+")
    begin
      file.write("数据库会员数量 #{members.size}\n")
      for pair in majias
        file.write(pair[0].ip_inspect + ' <=> ' + pair[1].ip_inspect + "\n")
      end
      if (s = file2.readline.gsub("\n", '')) != ''
        ip = IP_Address.new(s)
        s = "\n查询ip #{ip.to_s}\n"
        for member in members
          if member.ip_match?(ip, ip_difference)
            s += member.ip_inspect + "\n"
          end
        end
        file.write(s)
      end
    ensure
      file.close
      file2.close
    end
  end
  #--------------------------------------------------------------------------
  # ● 检测马甲
  #    数组单元：ID1,ID2
  #--------------------------------------------------------------------------
  def find_majia(members, ip_difference = 0)
    majias = []
    for i in 0...members.size - 1
      for j in i + 1...members.size
        if members[i].majia?(members[j], ip_difference)
          majias.push([members[i], members[j]])
        end
      end
    end
    return majias
  end
  #--------------------------------------------------------------------------
  # ● 初始化精灵
  #--------------------------------------------------------------------------
  def ini_sprite
    if @progress_sprite == nil
      @progress_sprite = Sprite.new
      @progress_sprite.bitmap = Bitmap.new(64, 32)
      @progress_sprite.ox = @progress_sprite.bitmap.width / 2
      @progress_sprite.oy = @progress_sprite.bitmap.height / 2
      @progress_sprite.x = 640 / 2
      @progress_sprite.y = 480 / 2
      draw_progress(0, 1)
    end
  end
  #--------------------------------------------------------------------------
  # ● 描绘进度
  #--------------------------------------------------------------------------
  def draw_progress(n, max)
    num = n * 100 / max
    @progress_sprite.bitmap.clear
    @progress_sprite.bitmap.draw_text(0, 0,
    @progress_sprite.bitmap.width, @progress_sprite.bitmap.height,
    num.to_s + '%', 2)
    Graphics.update
  end
end

#==============================================================================
# ■ User_6R
#------------------------------------------------------------------------------
# 　6R用户
#==============================================================================
class User_6R
  #--------------------------------------------------------------------------
  # ● 实例变量
  #--------------------------------------------------------------------------
  attr_accessor :name
  attr_accessor :viewing
  attr_accessor :current_ip
  attr_accessor :all_ip
  #--------------------------------------------------------------------------
  # ● 初始化
  #--------------------------------------------------------------------------
  def initialize(name, viewing, ip_address)
    @name = make_name(name)
    @viewing = make_viewing(viewing)
    @current_ip = IP_Address.new(ip_address)
    @all_ip = [IP_Address.new(ip_address)]
  end
  #--------------------------------------------------------------------------
  # ● 处理名字
  #--------------------------------------------------------------------------
  def make_name(name)
    name.slice(/\<a.*?\>(.*?)\<\/a\>/)
    if $1 == nil
      return name
    else
      return $1
    end
  end
  #--------------------------------------------------------------------------
  # ● 处理查看网页
  #--------------------------------------------------------------------------
  def make_viewing(viewing)
    viewing.slice(/\<a.*?\>(.*?)\<\/a\>/)
    if $1 == nil
      return viewing
    else
      return $1
    end
  end
  #--------------------------------------------------------------------------
  # ● 是否会员
  #--------------------------------------------------------------------------
  def member?
    return @name != '游客'
  end
  #--------------------------------------------------------------------------
  # ● 是否马甲
  #--------------------------------------------------------------------------
  def majia?(other, ip_difference = 0)
    for ip1 in @all_ip
      for ip2 in other.all_ip
        if ip1.match(ip2) <= ip_difference
          return true
        end
      end
    end
    return false
  end
  #--------------------------------------------------------------------------
  # ● ip对应
  #--------------------------------------------------------------------------
  def ip_match?(ip, ip_difference = 0)
    for ip2 in @all_ip
      if ip.match(ip2) <= ip_difference
        return true
      end
    end
    return false
  end
  #--------------------------------------------------------------------------
  # ● 输出信息
  #--------------------------------------------------------------------------
  def inspect
    return sprintf('%-16s %-15s %s', @name, @current_ip, @viewing)
  end
  #--------------------------------------------------------------------------
  # ● 输出名字和IP信息
  #--------------------------------------------------------------------------
  def ip_inspect
    return (@name + ' ' + @all_ip.join(' '))
  end
  #--------------------------------------------------------------------------
  # ● 字符串
  #--------------------------------------------------------------------------
  def to_s
    return @name
  end
  #--------------------------------------------------------------------------
  # ● 对比
  #--------------------------------------------------------------------------
  def ==(other)
    return @name == other.name
  end
  #--------------------------------------------------------------------------
  # ● 排序
  #--------------------------------------------------------------------------
  def <=>(other)
    return @name <=> other.name
  end
  #--------------------------------------------------------------------------
  # ● 加入IP
  #--------------------------------------------------------------------------
  def add_ip(ip)
    if not @all_ip.include?(ip)
      @all_ip.push(ip)
    end
  end
end

#==============================================================================
# ■ IP_Address
#------------------------------------------------------------------------------
# 　IP地址
#==============================================================================

class IP_Address
  #--------------------------------------------------------------------------
  # ● 实例变量
  #--------------------------------------------------------------------------
  attr_accessor :parts
  #--------------------------------------------------------------------------
  # ● 初始化
  #--------------------------------------------------------------------------
  def initialize(string)
    @parts = []
    if string != nil
      string.scan(/(\d+|\*)/){|matched|
        for part in matched
          if part == '*' 
            @parts.push(-1)
          else
            @parts.push(part.to_i)
          end
        end
      }
    end
    while @parts.size < 4
      @parts.push(-1)
    end
  end
  #--------------------------------------------------------------------------
  # ● 对比
  #--------------------------------------------------------------------------
  def ==(other)
    return @parts == other.parts
  end
  #--------------------------------------------------------------------------
  # ● 吻合度
  #--------------------------------------------------------------------------
  def match(other)
    max = 0
    for i in 0...@parts.size
      diff = (@parts[i] - other.parts[i]).abs
      if diff > max
        max = diff
      end
    end
    return max
  end
  #--------------------------------------------------------------------------
  # ● 字符串
  #--------------------------------------------------------------------------
  def to_s
    return @parts.join('.').gsub('-1', '*')
  end
end

Eye_of_6R.loop_run
#Eye_of_6R.run
#Eye_of_6R.print_majia(0)
#Eye_of_6R.merge_data