import storage from '@ohos.data.preferences';
import mediaQuery from '@ohos.mediaquery';
import window from '@ohos.window';
import promptAction from '@ohos.promptAction';
import vibrator from '@ohos.vibrator';

enum Priority {
  LOW = 'Low',
  MEDIUM = 'Medium',
  HIGH = 'High'
}

enum SortOption {
  DATE = 'Date',
  PRIORITY = 'Priority',
  ALPHABETICAL = 'Alphabetical'
}

// 主题模式
enum ThemeMode {
  LIGHT = 'Light',
  DARK = 'Dark',
  SYSTEM = 'System'
}

// 主题颜色接口
interface ThemeColors {
  background: string;
  backgroundSecondary: string;
  textPrimary: string;
  textSecondary: string;
  textDisabled: string;
  primary: string;
  cardBackground: string;
  cardBorder: string;
  priorityHigh: string;
  priorityMedium: string;
  priorityLow: string;
  inputBackground: string;
  switchBackground: string;
  emptyState: string;
}

// 主题颜色配置
class AppTheme {
  static readonly LIGHT: ThemeColors = {
    // 背景色
    background: '#F2F2F7',
    backgroundSecondary: '#FFFFFF',
    // 文本色
    textPrimary: '#000000',
    textSecondary: '#8E8E93',
    textDisabled: '#C7C7CC',
    // 强调色
    primary: '#007AFF',
    // 卡片背景
    cardBackground: '#FFFFFF',
    cardBorder: 'rgba(0, 0, 0, 0.1)',
    // 优先级颜色
    priorityHigh: '#FF3B30',
    priorityMedium: '#FF9500',
    priorityLow: '#34C759',
    // 表单元素
    inputBackground: '#FFFFFF',
    switchBackground: '#E5E5EA',
    // 空状态
    emptyState: '#E5E5EA',
  };
  
  static readonly DARK: ThemeColors = {
    // 背景色
    background: '#1C1C1E',
    backgroundSecondary: '#2C2C2E',
    // 文本色
    textPrimary: '#FFFFFF',
    textSecondary: '#8E8E93',
    textDisabled: '#48484A',
    // 强调色
    primary: '#0A84FF',
    // 卡片背景
    cardBackground: '#2C2C2E',
    cardBorder: 'rgba(255, 255, 255, 0.1)',
    // 优先级颜色
    priorityHigh: '#FF453A',
    priorityMedium: '#FF9F0A',
    priorityLow: '#32D74B',
    // 表单元素
    inputBackground: '#2C2C2E',
    switchBackground: '#48484A',
    // 空状态
    emptyState: '#48484A',
  };
}

// Interface for todo item data from storage
interface TodoItemData {
  id: number;
  text: string;
  isCompleted: boolean;
  createdAt: string;
  priority: Priority;
  dueDate?: string | null;  // 截止日期可能是undefined或null
  hasReminder?: boolean;  // 是否有提醒
}

// 定义字体尺寸配置接口
interface FontSizeConfig {
  title: number,
  subtitle: number,
  normal: number,
  small: number
}

// 统计数据项接口
interface PriorityStatItem {
  priority: Priority;
  count: number;
  color: string;
}

// 对话框按钮接口
interface DialogButton {
  text: string;
  color: string;
}

// 日期选择器数据接口
interface DatePickerInfo {
  year: number;
  month: number;
  day: number;
}

// 定义响应接口
class DialogResponse {
  index: number = 0;
}

// 文件选择器命名选项
interface FileNameOptions {
  defaultName: string;
}

// Interfaz para propiedades de la barra del sistema de la ventana
interface WindowSystemBarProperties {
  statusBarColor: string;
  statusBarContentColor: string;
  navigationBarColor: string;
  navigationBarContentColor: string;
}

@Entry
@Component
struct Index {
  @State todoList: TodoItem[] = [];
  @State newTodoText: string = '';
  @State selectedPriority: Priority = Priority.MEDIUM;
  @State sortOption: SortOption = SortOption.DATE;
  @State showCompletedTasks: boolean = true;
  @State isAddingNew: boolean = false;
  @State listAnimated: boolean = false;
  
  // 搜索相关状态
  @State searchQuery: string = '';
  @State isSearching: boolean = false;
  @State selectedFilter: string = '全部';  // 可选值: '全部', '今天', '重要'
  
  // 主题相关状态
  @State themeMode: ThemeMode = ThemeMode.SYSTEM;
  @State isDarkMode: boolean = false;
  @State colors: ThemeColors = AppTheme.LIGHT;
  private systemDarkModeListener = mediaQuery.matchMediaSync('(prefers-color-scheme: dark)');
  
  // 响应式布局相关状态
  @State isTablet: boolean = false;
  @State isLandscape: boolean = false;
  @State screenWidth: number = 0;
  @State contentMaxWidth: Length = '90%';  // 使用Length类型，可以接受百分比字符串
  @State fontSize: FontSizeConfig = { title: 34, subtitle: 18, normal: 16, small: 14 };
  
  private tabletListener = mediaQuery.matchMediaSync('(min-width: 600vp)');
  private landscapeListener = mediaQuery.matchMediaSync('(orientation: landscape)');
  private preferencesKey: string = 'todoListData';
  private preferencesThemeKey: string = 'themeMode';
  private preferences: storage.Preferences | null = null;
  
  // 统计相关状态
  @State showStatistics: boolean = false;
  
  // 截止日期相关状态
  @State selectedDueDate: Date | null = null;
  @State hasReminder: boolean = false;
  @State showDatePicker: boolean = false;
  @State tempSelectedDate: Date = new Date();

  // 编辑任务相关状态
  @State editingTask: TodoItem | null = null;
  @State editTaskText: string = '';
  @State editTaskPriority: Priority = Priority.MEDIUM;
  @State editTaskDueDate: Date | null = null;
  @State editTaskHasReminder: boolean = false;
  @State showEditTaskPanel: boolean = false;
  
  // DatePicker处理函数
  tempDateCallback: (date: Date) => void = () => {};

  // 日期选择处理
  @State datePickerInfo: DatePickerInfo = {
    year: new Date().getFullYear(),
    month: new Date().getMonth() + 1,
    day: new Date().getDate()
  };

  aboutToAppear() {
    // Initialize preferences and load saved todos
    this.initPreferences();
    
    // 设置屏幕适配的监听器
    this.tabletListener.on('change', (_) => {
      this.isTablet = this.tabletListener.matches;
      this.updateLayoutParams();
    });
    
    this.landscapeListener.on('change', (_) => {
      this.isLandscape = this.landscapeListener.matches;
      this.updateLayoutParams();
    });
    
    // 设置系统主题监听
    this.systemDarkModeListener.on('change', (_) => {
      if (this.themeMode === ThemeMode.SYSTEM) {
        this.updateTheme(ThemeMode.SYSTEM);
      }
    });
    
    // 初始化响应式状态
    this.isTablet = this.tabletListener.matches;
    this.isLandscape = this.landscapeListener.matches;
    this.updateLayoutParams();
    
    // 延迟触发列表动画
    setTimeout(() => {
      this.listAnimated = true;
    }, 100);
  }
  
  aboutToDisappear() {
    // 移除监听器
    this.tabletListener.off('change');
    this.landscapeListener.off('change');
    this.systemDarkModeListener.off('change');
  }
  
  // 初始化Preferences并加载数据
  async initPreferences() {
    try {
      this.preferences = await storage.getPreferences(getContext(this), 'TodoApp');
      
      // 加载主题设置
      const savedTheme = await this.preferences.get(this.preferencesThemeKey, ThemeMode.SYSTEM);
      this.updateTheme(savedTheme as ThemeMode);
      
      // 加载待办事项数据
      const todoData = await this.preferences.get(this.preferencesKey, '[]');
      const parsedData = JSON.parse(todoData as string) as TodoItemData[];
      
      // Convert plain objects back to TodoItem instances
      this.todoList = parsedData.map((item: TodoItemData) => {
        const todoItem = new TodoItem(
          item.text, 
          item.priority || Priority.MEDIUM,
          item.dueDate ? new Date(item.dueDate) : null,
          item.hasReminder || false
        );
        todoItem.id = item.id;
        todoItem.isCompleted = item.isCompleted;
        todoItem.createdAt = new Date(item.createdAt);
        return todoItem;
      });
      
      this.sortTodos();
      
      // 检查是否有需要提醒的任务
      this.checkReminders();
    } catch (error) {
      console.error('Failed to load preferences:', error);
      this.todoList = [];
      // 默认使用系统主题
      this.updateTheme(ThemeMode.SYSTEM);
    }
  }
  
  // 更新主题设置
  async updateTheme(mode: ThemeMode) {
    this.themeMode = mode;
    
    // 根据主题模式决定是否使用暗色模式
    if (mode === ThemeMode.DARK) {
      this.isDarkMode = true;
      this.colors = AppTheme.DARK;
    } else if (mode === ThemeMode.LIGHT) {
      this.isDarkMode = false;
      this.colors = AppTheme.LIGHT;
    } else {
      // 跟随系统主题
      const isDarkSystem = this.systemDarkModeListener.matches;
      this.isDarkMode = isDarkSystem;
      this.colors = isDarkSystem ? AppTheme.DARK : AppTheme.LIGHT;
    }
    
    // 更新状态栏颜色
    this.updateStatusBarColor();
    
    // 保存主题设置到Preferences
    if (this.preferences) {
      await this.preferences.put(this.preferencesThemeKey, mode);
      await this.preferences.flush();
    }
  }
  
  // 更新状态栏颜色
  async updateStatusBarColor() {
    try {
      const windowClass = await window.getLastWindow(getContext(this));
      
      // 设置状态栏颜色
      let barProperties: WindowSystemBarProperties;
      
      if (this.isDarkMode) {
        windowClass.setWindowBackgroundColor('#1C1C1E');
        barProperties = {
          statusBarColor: '#1C1C1E',
          statusBarContentColor: '#FFFFFF',
          navigationBarColor: '#1C1C1E',
          navigationBarContentColor: '#FFFFFF'
        };
      } else {
        windowClass.setWindowBackgroundColor('#F2F2F7');
        barProperties = {
          statusBarColor: '#F2F2F7',
          statusBarContentColor: '#000000',
          navigationBarColor: '#F2F2F7',
          navigationBarContentColor: '#000000'
        };
      }
      
      windowClass.setWindowSystemBarProperties(barProperties);
    } catch (error) {
      console.error('Failed to update status bar color:', error);
    }
  }
  
  // 更新布局参数
  updateLayoutParams() {
    // 根据屏幕尺寸调整布局参数
    if (this.isTablet) {
      this.fontSize = { 
        title: 40, 
        subtitle: 22, 
        normal: 18, 
        small: 16 
      };
      this.contentMaxWidth = this.isLandscape ? '70%' : '85%';
    } else {
      this.fontSize = { 
        title: 34, 
        subtitle: 18, 
        normal: 16, 
        small: 14 
      };
      this.contentMaxWidth = this.isLandscape ? '85%' : '90%';
    }
  }

  async saveTodos() {
    if (this.preferences) {
      try {
        await this.preferences.put(this.preferencesKey, JSON.stringify(this.todoList));
        await this.preferences.flush();
      } catch (error) {
        console.error('Failed to save todos:', error);
      }
    }
  }

  async addTodo() {
    if (this.newTodoText.trim() !== '') {
      this.todoList.push(new TodoItem(
        this.newTodoText.trim(), 
        this.selectedPriority,
        this.selectedDueDate,
        this.hasReminder
      ));
      this.newTodoText = '';
      this.selectedDueDate = null;
      this.hasReminder = false;
      this.sortTodos();
      await this.saveTodos();
      this.isAddingNew = false;
      
      // 如果有提醒，创建提醒通知
      // 注意：为简化示例，这里不创建实际的系统提醒，仅显示提示
      if (this.hasReminder && this.selectedDueDate) {
        this.showToast('提醒已设置');
      }
    }
  }

  async toggleTodoComplete(index: number) {
    this.todoList[index].isCompleted = !this.todoList[index].isCompleted;
    await this.saveTodos();
  }

  async deleteTodo(index: number) {
    this.todoList.splice(index, 1);
    await this.saveTodos();
  }
  
  sortTodos() {
    switch (this.sortOption) {
      case SortOption.DATE:
        this.todoList.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        break;
      case SortOption.PRIORITY:
        this.todoList.sort((a, b) => {
          const valueA = a.priority === Priority.HIGH ? 0 : a.priority === Priority.MEDIUM ? 1 : 2;
          const valueB = b.priority === Priority.HIGH ? 0 : b.priority === Priority.MEDIUM ? 1 : 2;
          return valueA - valueB;
        });
        break;
      case SortOption.ALPHABETICAL:
        this.todoList.sort((a, b) => a.text.localeCompare(b.text));
        break;
    }
  }

  getFilteredTodos(): TodoItem[] {
    // 应用搜索和过滤条件
    let filteredList = this.todoList.filter(item => {
      // 按完成状态过滤
      if (!this.showCompletedTasks && item.isCompleted) {
        return false;
      }
      
      // 按搜索关键词过滤
      if (this.searchQuery.trim() !== '' && 
          !item.text.toLowerCase().includes(this.searchQuery.toLowerCase())) {
        return false;
      }
      
      // 按类别过滤
      if (this.selectedFilter === '今天') {
        const now = new Date();
        const itemDate = new Date(item.createdAt);
        if (itemDate.getDate() !== now.getDate() || 
            itemDate.getMonth() !== now.getMonth() || 
            itemDate.getFullYear() !== now.getFullYear()) {
          return false;
        }
      } else if (this.selectedFilter === '重要') {
        if (item.priority !== Priority.HIGH) {
          return false;
        }
      }
      
      return true;
    });
    
    return filteredList;
  }
  
  // 切换选定的过滤器
  setFilter(filter: string) {
    this.selectedFilter = filter;
  }
  
  // 搜索任务
  searchTodos(query: string) {
    this.searchQuery = query;
  }
  
  // 清除搜索和过滤
  clearSearch() {
    this.searchQuery = '';
    this.isSearching = false;
  }

  // 获取任务完成百分比
  getCompletionPercentage(): number {
    if (this.todoList.length === 0) return 0;
    const completedCount = this.todoList.filter(item => item.isCompleted).length;
    return Math.round((completedCount / this.todoList.length) * 100);
  }
  
  // 获取各优先级任务的统计
  getPriorityStats(): PriorityStatItem[] {
    const highStat: PriorityStatItem = { priority: Priority.HIGH, count: 0, color: this.colors.priorityHigh };
    const mediumStat: PriorityStatItem = { priority: Priority.MEDIUM, count: 0, color: this.colors.priorityMedium };
    const lowStat: PriorityStatItem = { priority: Priority.LOW, count: 0, color: this.colors.priorityLow };
    
    const stats: PriorityStatItem[] = [highStat, mediumStat, lowStat];
    
    // 计算每个优先级的任务数量
    this.todoList.forEach(item => {
      switch (item.priority) {
        case Priority.HIGH:
          highStat.count++;
          break;
        case Priority.MEDIUM:
          mediumStat.count++;
          break;
        case Priority.LOW:
          lowStat.count++;
          break;
      }
    });
    
    return stats;
  }
  
  // 检查是否有需要提醒的任务
  checkReminders() {
    const now = new Date();
    const overdueItems = this.todoList.filter(item => 
      !item.isCompleted && 
      item.hasReminder && 
      item.dueDate && 
      item.dueDate.getTime() < now.getTime()
    );
    
    // 对于过期的任务，发送提醒
    if (overdueItems.length > 0) {
      this.showToast(`有 ${overdueItems.length} 个任务已过期`);
    }
  }
  
  // 显示日期选择器
  showDatePickerDialog() {
    this.tempSelectedDate = this.selectedDueDate || new Date();
    this.showDatePicker = true;
  }
  
  // 确认选择的日期
  confirmDateSelection() {
    this.selectedDueDate = new Date(this.tempSelectedDate);
    this.showDatePicker = false;
  }
  
  // 取消日期选择
  cancelDateSelection() {
    this.showDatePicker = false;
  }

  // 设置临时日期回调函数
  setTempDateCallback(callback: (date: Date) => void) {
    this.tempDateCallback = callback;
  }
  
  // 处理日期选择器的值变化
  handleDatePickerChange(value: DatePickerInfo) {
    if (value && typeof value === 'object' && value.year !== undefined && value.month !== undefined && value.day !== undefined) {
      this.datePickerInfo = value;
      const date = new Date(value.year, value.month - 1, value.day);
      this.tempSelectedDate = date;
      this.tempDateCallback(date);
    }
  }
  
  // 格式化日期
  formatDate(date: Date | null): string {
    if (!date) return '';
    
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(now.getDate() + 1);
    
    if (date.getDate() === now.getDate() && 
        date.getMonth() === now.getMonth() && 
        date.getFullYear() === now.getFullYear()) {
      return '今天';
    } else if (date.getDate() === tomorrow.getDate() && 
               date.getMonth() === tomorrow.getMonth() && 
               date.getFullYear() === tomorrow.getFullYear()) {
      return '明天';
    } else {
      return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
    }
  }
  
  // 显示提示消息
  showToast(message: string) {
    promptAction.showToast({
      message: message,
      duration: 2000,
      bottom: '50%'
    });
  }
  
  // 设置截止日期
  setDueDate(date: Date | null) {
    this.selectedDueDate = date;
    
    // 如果清除截止日期，也清除提醒
    if (!date) {
      this.hasReminder = false;
    }
  }

  // 开始编辑任务
  startEditTask(item: TodoItem) {
    this.editingTask = item;
    this.editTaskText = item.text;
    this.editTaskPriority = item.priority;
    this.editTaskDueDate = item.dueDate;
    this.editTaskHasReminder = item.hasReminder;
    this.showEditTaskPanel = true;
  }
  
  // 保存编辑后的任务
  async saveEditTask() {
    if (this.editingTask && this.editTaskText.trim() !== '') {
      const index = this.todoList.findIndex(item => item.id === this.editingTask?.id);
      if (index !== -1) {
        this.todoList[index].text = this.editTaskText.trim();
        this.todoList[index].priority = this.editTaskPriority;
        this.todoList[index].dueDate = this.editTaskDueDate;
        this.todoList[index].hasReminder = this.editTaskHasReminder;
        
        this.sortTodos();
        await this.saveTodos();
        this.cancelEditTask();
        
        this.showToast('任务已更新');
      }
    }
  }
  
  // 取消编辑任务
  cancelEditTask() {
    this.editingTask = null;
    this.editTaskText = '';
    this.editTaskDueDate = null;
    this.editTaskHasReminder = false;
    this.showEditTaskPanel = false;
  }
  
  // 振动反馈
  vibrateShort() {
    try {
      // Vibración corta de 10ms
      vibrator.vibrate(10);
    } catch (error) {
      console.error('Failed to vibrate:', error);
    }
  }

  // 获取优先级颜色
  getPriorityColor(priority: Priority): string {
    switch (priority) {
      case Priority.HIGH:
        return this.colors.priorityHigh;
      case Priority.MEDIUM:
        return this.colors.priorityMedium;
      case Priority.LOW:
        return this.colors.priorityLow;
      default:
        return this.colors.textSecondary;
    }
  }
  
  // 清空所有任务
  async clearAllTasks() {
    try {
      const dialogButtons: Array<DialogButton> = [
        {
          text: '取消',
          color: '#8E8E93'
        },
        {
          text: '确定删除',
          color: '#FF3B30'
        }
      ];
      
      const dialogOptions: promptAction.ShowDialogOptions = {
        title: '确认清空',
        message: '确定要删除所有任务吗？此操作无法撤销。',
        buttons: dialogButtons
      };
      
      // 显示确认对话框
      const result: DialogResponse = await promptAction.showDialog(dialogOptions) as DialogResponse;
      if (result && result.index === 1) {
        // 用户确认清空
        this.todoList = [];
        await this.saveTodos();
        this.showToast('已清空所有任务');
      }
    } catch (error) {
      console.error('对话框显示失败:', error);
      this.showToast('对话框显示失败: ' + String(error));
    }
  }

  build() {
    Row() {
      // 处理横屏布局 - 可以添加侧边栏
      if (this.isLandscape && this.isTablet) {
        Column() {
          Row() {
            Text('Todo分类')
              .fontSize(this.fontSize.subtitle)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.textPrimary)
              .padding(16)
            
            Blank()
            
            // 主题切换按钮
            Button() {
              Column() {
                Text(this.isDarkMode ? '☀️' : '🌙')
                  .fontSize(20)
                  .fontColor(this.isDarkMode ? '#FFFFFF' : '#000000')
              }
            }
            .width(40)
            .height(40)
            .backgroundColor('transparent')
            .margin({ right: 16 })
            .onClick(() => {
              this.updateTheme(this.isDarkMode ? ThemeMode.LIGHT : ThemeMode.DARK);
            })
          }
          .width('100%')
          
          Divider()
            .width('80%')
            .color(this.colors.textDisabled)
          
          Column() {
            Button() {
              Column() {
                Text('全部任务')
                  .width('100%')
                  .height(50)
                  .fontSize(this.fontSize.normal)
                  .fontColor(this.selectedFilter === '全部' ? '#FFFFFF' : this.colors.primary)
              }
            }
            .width('90%')
            .height(50)
            .margin({ top: 16 })
            .backgroundColor(this.selectedFilter === '全部' ? this.colors.primary : this.colors.switchBackground)
            .borderRadius(8)
            .onClick(() => {
              this.setFilter('全部');
            })
            
            Button() {
              Column() {
                Text('今日任务')
                  .width('100%')
                  .height(50)
                  .fontSize(this.fontSize.normal)
                  .fontColor(this.selectedFilter === '今天' ? '#FFFFFF' : this.colors.primary)
              }
            }
            .width('90%')
            .height(50)
            .margin({ top: 16 })
            .backgroundColor(this.selectedFilter === '今天' ? this.colors.primary : this.colors.switchBackground)
            .borderRadius(8)
            .onClick(() => {
              this.setFilter('今天');
            })
              
            Button() {
              Column() {
                Text('重要任务')
                  .width('100%')
                  .height(50)
                  .fontSize(this.fontSize.normal)
                  .fontColor(this.selectedFilter === '重要' ? '#FFFFFF' : this.colors.priorityHigh)
              }
            }
            .width('90%')
            .height(50)
            .margin({ top: 16 })
            .backgroundColor(this.selectedFilter === '重要' ? this.colors.primary : this.colors.switchBackground)
            .borderRadius(8)
            .onClick(() => {
              this.setFilter('重要');
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .layoutWeight(1)
        }
        .width('30%')
        .height('100%')
        .backgroundColor(this.colors.background)
        .padding({ top: 48 })
      }
      
      // 主内容区域
      Column() {
        // Header section
        Row() {
          Column() {
            Text('Todo')
              .fontSize(this.fontSize.title)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.textPrimary)

            Text(`${this.todoList.length} 任务 | ${this.todoList.filter(item => item.isCompleted).length} 已完成`)
              .fontSize(this.fontSize.small)
              .fontColor(this.colors.textSecondary)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()
          
          // 统计按钮
          Button() {
            Column() {
              Text('📊')
                .fontSize(20)
                .fontColor(this.isDarkMode ? '#FFFFFF' : '#000000')
            }
          }
          .width(40)
          .height(40)
          .backgroundColor('transparent')
          .margin({ right: 8 })
          .onClick(() => {
            this.showStatistics = !this.showStatistics;
          })
          
          // 主题切换按钮
          if (!(this.isLandscape && this.isTablet)) {
            Button() {
              Column() {
                Text(this.isDarkMode ? '☀️' : '🌙')
                  .fontSize(20)
                  .fontColor(this.isDarkMode ? '#FFFFFF' : '#000000')
              }
            }
            .width(40)
            .height(40)
            .backgroundColor('transparent')
            .margin({ right: 16 })
            .onClick(() => {
              this.updateTheme(this.isDarkMode ? ThemeMode.LIGHT : ThemeMode.DARK);
            })
          }

          Row() {
            Toggle({ type: ToggleType.Switch, isOn: this.showCompletedTasks })
              .onChange((isOn: boolean) => {
                this.showCompletedTasks = isOn;
              })
              .width(50)
              .height(28)
              .selectedColor(this.colors.primary)
            
            Text('显示已完成')
              .fontSize(this.fontSize.small)
              .fontColor(this.colors.textSecondary)
              .margin({ left: 8 })
          }
        }
        .width(this.contentMaxWidth)
        .padding({ top: this.isTablet ? 64 : 48, bottom: 24 })
        
        // 统计面板 (仅在showStatistics为true时显示)
        if (this.showStatistics) {
          Column() {
            // 标题
            Text('任务统计')
              .fontSize(this.fontSize.subtitle)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.textPrimary)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })
            
            // 简化的统计信息
            Row() {
              // 完成率
              Column() {
                Text(`${this.getCompletionPercentage()}%`)
                  .fontSize(this.fontSize.subtitle)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.colors.textPrimary)
                  
                Text('已完成')
                  .fontSize(this.fontSize.small)
                  .fontColor(this.colors.textSecondary)
              }
              .alignItems(HorizontalAlign.Center)
              .layoutWeight(1)
              .height('100%')
              .backgroundColor(this.colors.cardBackground)
              .borderRadius(12)
              .padding(16)
            }
            .width('100%')
            .height(this.isTablet ? 100 : 80)
          }
          .width(this.contentMaxWidth)
          .padding(10)
          .backgroundColor(this.isDarkMode ? 'rgba(0, 0, 0, 0.1)' : 'rgba(0, 0, 0, 0.02)')
          .borderRadius(16)
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
          .margin({ bottom: 20 })
        }
        
        // 搜索栏
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            TextInput({ placeholder: '搜索任务...', text: this.searchQuery })
              .width('100%')
              .height(this.isTablet ? 50 : 44)
              .borderRadius(22)
              .backgroundColor(this.colors.inputBackground)
              .placeholderColor(this.colors.textSecondary)
              .padding({ left: 44, right: 16 })
              .fontSize(this.fontSize.normal)
              .fontColor(this.colors.textPrimary)
              .onChange((value: string) => {
                this.searchTodos(value);
              })
              .onSubmit(() => {
                // 当用户按下搜索或回车键时触发
                this.isSearching = this.searchQuery.trim() !== '';
              })
              
            // 搜索图标
            Text('🔍')
              .fontSize(20)
              .fontColor(this.colors.textSecondary)
              .margin({ left: 16 })
              .position({ x: 0, y: '50%' })
              .translate({ y: -12 })
              
            // 清除按钮 (仅在有搜索文本时显示)
            if (this.searchQuery.length > 0) {
              Button() {
                Column() {
                  Circle()
                    .width(16)
                    .height(16)
                    .fill(this.colors.textSecondary)
                  
                  Text('×')
                    .fontSize(12)
                    .fontColor(this.isDarkMode ? '#000000' : '#FFFFFF')
                    .position({ x: '50%', y: '50%' })
                    .translate({ x: -6, y: -9 })
                }
              }
              .width(20)
              .height(20)
              .backgroundColor('transparent')
              .position({ x: '95%', y: '50%' })
              .translate({ x: -20, y: -10 })
              .onClick(() => {
                this.clearSearch();
              })
            }
          }
          .width('100%')
        }
        .width(this.contentMaxWidth)
        .margin({ bottom: 16 })
        
        // 过滤标签 (仅在非平板横屏模式下显示)
        if (!(this.isLandscape && this.isTablet)) {
          Row() {
            ForEach(['全部', '今天', '重要'], (filter: string) => {
              Text(filter)
                .fontSize(this.fontSize.small)
                .fontColor(this.selectedFilter === filter ? this.colors.primary : this.colors.textSecondary)
                .fontWeight(this.selectedFilter === filter ? FontWeight.Medium : FontWeight.Normal)
                .backgroundColor(this.selectedFilter === filter ? (this.isDarkMode ? '#2C2C2E' : '#E5E5EA') : 'transparent')
                .borderRadius(12)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ right: 8 })
                .onClick(() => {
                  this.setFilter(filter);
                })
            })
          }
          .width(this.contentMaxWidth)
          .margin({ bottom: 16 })
        }

        // Sorting section
        Row() {
          Text('排序:')
            .fontSize(this.fontSize.small)
            .fontColor(this.colors.textSecondary)
            .margin({ right: 10 })

          ForEach([SortOption.DATE, SortOption.PRIORITY, SortOption.ALPHABETICAL], (option: SortOption) => {
            Text(option)
              .fontSize(this.fontSize.small)
              .fontColor(this.sortOption === option ? this.colors.primary : this.colors.textSecondary)
              .fontWeight(this.sortOption === option ? FontWeight.Medium : FontWeight.Normal)
              .margin({ right: 16 })
              .onClick(() => {
                this.sortOption = option;
                this.sortTodos();
              })
          })

          Blank()

          Button() {
            Column() {
              Text('+')
                .fontSize(this.fontSize.subtitle)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
            }
          }
          .width(this.isTablet ? 42 : 36)
          .height(this.isTablet ? 42 : 36)
          .backgroundColor(this.colors.primary)
          .borderRadius(this.isTablet ? 21 : 18)
          .onClick(() => {
            this.isAddingNew = true;
          })
        }
        .width(this.contentMaxWidth)
        .margin({ bottom: 20 })

        // Add new task panel (only visible when adding)
        if (this.isAddingNew) {
          Column() {
            TextInput({ placeholder: '添加新的任务...', text: this.newTodoText })
              .onChange((value: string) => {
                this.newTodoText = value;
              })
              .width('100%')
              .height(this.isTablet ? 60 : 50)
              .borderRadius(8)
              .backgroundColor(this.colors.inputBackground)
              .placeholderColor(this.colors.textSecondary)
              .padding(16)
              .margin({ bottom: 16 })
              .fontColor(this.colors.textPrimary)
              .fontSize(this.fontSize.normal)
            
            // 截止日期选择器
            Row() {
              Text('截止日期:')
                .fontSize(this.fontSize.small)
                .fontColor(this.colors.textSecondary)
                .margin({ right: 12 })
              
              if (this.selectedDueDate) {
                // 显示已选择的日期
                Button() {
                  Column() {
                    Row() {
                      Text(this.formatDate(this.selectedDueDate))
                        .fontSize(this.fontSize.small)
                        .fontColor(this.colors.primary)
                      
                      Text(' ×')
                        .fontSize(this.fontSize.small)
                        .fontColor(this.colors.primary)
                        .margin({ left: 8 })
                    }
                  }
                }
                .backgroundColor(this.isDarkMode ? 'rgba(10, 132, 255, 0.2)' : 'rgba(0, 122, 255, 0.1)')
                .borderRadius(8)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.setDueDate(null);
                })
              } else {
                // 添加截止日期按钮
                Button() {
                  Column() {
                    Text('添加')
                      .fontSize(this.fontSize.small)
                      .fontColor(this.colors.primary)
                  }
                }
                .backgroundColor('transparent')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.tempSelectedDate = new Date();
                  this.showDatePicker = true;
                  
                  // 设置日期选择完成后的回调
                  this.setTempDateCallback((date: Date) => {
                    this.editTaskDueDate = date;
                  });
                })
              }
              
              Blank()
              
              // 提醒开关
              if (this.selectedDueDate) {
                Row() {
                  Text('提醒:')
                    .fontSize(this.fontSize.small)
                    .fontColor(this.colors.textSecondary)
                    .margin({ right: 8 })
                  
                  Toggle({ type: ToggleType.Checkbox, isOn: this.hasReminder })
                    .onChange((isOn: boolean) => {
                      this.hasReminder = isOn;
                    })
                    .width(20)
                    .height(20)
                    .selectedColor(this.colors.primary)
                }
              }
            }
            .width('100%')
            .margin({ bottom: 16 })
            
            // 日期选择器弹窗
            if (this.showDatePicker) {
              Column() {
                // 日期选择器
                DatePicker({
                  start: new Date('2020-01-01'),
                  end: new Date('2030-12-31'),
                  selected: this.tempSelectedDate,
                })
                  .onChange((value: DatePickerInfo) => {
                    this.handleDatePickerChange(value);
                  })
                  .backgroundColor(this.colors.cardBackground)
                  .width('100%')
                
                // 确认和取消按钮
                Row() {
                  Button() {
                    Column() {
                      Text('取消')
                        .fontSize(this.fontSize.normal)
                        .fontColor(this.colors.textSecondary)
                    }
                  }
                  .backgroundColor('transparent')
                  .onClick(() => {
                    this.cancelDateSelection();
                  })
                  
                  Blank()
                  
                  Button() {
                    Column() {
                      Text('确认')
                        .fontSize(this.fontSize.normal)
                        .fontColor(this.colors.primary)
                    }
                  }
                  .backgroundColor('transparent')
                  .onClick(() => {
                    this.confirmDateSelection();
                  })
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })
              }
              .width('100%')
              .backgroundColor(this.isDarkMode ? '#3C3C3E' : '#FFFFFF')
              .borderRadius(12)
              .padding(16)
              .margin({ bottom: 16 })
              .animation({
                duration: 200,
                curve: Curve.EaseOut,
                iterations: 1,
                playMode: PlayMode.Normal
              })
            }
            
            Row() {
              ForEach([Priority.LOW, Priority.MEDIUM, Priority.HIGH], (priority: Priority) => {
                Column() {
                  Circle()
                    .fill(this.getPriorityColor(priority))
                    .width(this.isTablet ? 20 : 16)
                    .height(this.isTablet ? 20 : 16)
                    .opacity(this.selectedPriority === priority ? 1 : 0.5)
                    
                  Text(priority)
                    .fontSize(this.fontSize.small)
                    .fontColor(this.selectedPriority === priority ? this.getPriorityColor(priority) : this.colors.textSecondary)
                    .fontWeight(this.selectedPriority === priority ? FontWeight.Medium : FontWeight.Normal)
                    .margin({ top: 8 })
                }
                .padding(12)
                .borderRadius(8)
                .backgroundColor(this.selectedPriority === priority ? (this.isDarkMode ? '#2C2C2E' : '#F2F2F7') : 'transparent')
                .margin({ right: 16 })
                .onClick(() => {
                  this.selectedPriority = priority;
                })
              })

              Blank()

              Row() {
                Button() {
                  Column() {
                    Text('取消')
                      .fontSize(this.fontSize.normal)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.colors.textSecondary)
                  }
                }
                .backgroundColor('transparent')
                .margin({ right: 16 })
                .onClick(() => {
                  this.cancelEditTask();
                })
                
                Button() {
                  Column() {
                    Text('添加')
                      .fontSize(this.fontSize.normal)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FFFFFF')
                  }
                }
                .backgroundColor(this.colors.primary)
                .borderRadius(8)
                .padding({ left: 16, right: 16, top: this.isTablet ? 8 : 4, bottom: this.isTablet ? 8 : 4 })
                .enabled(this.newTodoText.trim() !== '')
                .opacity(this.newTodoText.trim() !== '' ? 1 : 0.5)
                .onClick(() => {
                  this.addTodo();
                })
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width(this.contentMaxWidth)
          .padding(16)
          .backgroundColor(this.isDarkMode ? '#2C2C2E' : '#F2F2F7')
          .borderRadius(12)
          .margin({ bottom: 20 })
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
        }

        // 搜索结果统计 (仅在搜索时显示)
        if (this.searchQuery.trim() !== '') {
          Text(`找到 ${this.getFilteredTodos().length} 个结果`)
            .fontSize(this.fontSize.small)
            .fontColor(this.colors.textSecondary)
            .width(this.contentMaxWidth)
            .margin({ bottom: 12 })
        }

        // Todo list
        List({ space: this.isTablet ? 12 : 8 }) {
          ForEach(this.getFilteredTodos(), (item: TodoItem, index: number) => {
            ListItem() {
              TodoItemComponent({
                item: item,
                onDelete: () => {
                  this.deleteTodo(index);
                },
                onToggleComplete: () => {
                  this.toggleTodoComplete(index);
                },
                onEdit: (item: TodoItem) => {
                  this.startEditTask(item);
                },
                animationDelay: index * 50,
                isTablet: this.isTablet,
                fontSize: this.fontSize,
                colors: this.colors,
                isDarkMode: this.isDarkMode
              })
            }
            .opacity(this.listAnimated ? 1 : 0)
            .animation({
              duration: 300,
              curve: Curve.EaseOut,
              delay: index * 50,
              iterations: 1,
              playMode: PlayMode.Normal,
              onFinish: () => {
                // 动画完成后的回调，如果需要的话
              }
            })
          })
        }
        .width(this.contentMaxWidth)
        .layoutWeight(1)

        // 空状态信息
        if (this.getFilteredTodos().length === 0) {
          Column() {
            Text('☑')
              .fontSize(this.isTablet ? 72 : 56)
              .fontColor(this.colors.emptyState)
              .margin({ bottom: 16 })
              
            if (this.searchQuery.trim() !== '') {
              // 无搜索结果状态
              Text('没有找到匹配的任务')
                .fontSize(this.fontSize.subtitle)
                .fontColor(this.colors.textSecondary)
                .fontWeight(FontWeight.Medium)
                
              Text('尝试使用不同的搜索词或过滤器')
                .fontSize(this.fontSize.small)
                .fontColor(this.colors.textSecondary)
                .margin({ top: 8 })
            } else {
              // 无任务状态
              Text('没有任务')
                .fontSize(this.fontSize.subtitle)
                .fontColor(this.colors.textSecondary)
                .fontWeight(FontWeight.Medium)
                
              Text(this.isAddingNew ? '点击"添加"按钮创建新的任务' : '点击"+"按钮创建新的任务')
                .fontSize(this.fontSize.small)
                .fontColor(this.colors.textSecondary)
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .opacity(this.listAnimated ? 1 : 0)
          .animation({
            duration: 500,
            curve: Curve.EaseOut,
            delay: 100,
            iterations: 1,
            playMode: PlayMode.Normal
          })
        }

        // Edit task panel
        if (this.showEditTaskPanel) {
          Column() {
            Text('编辑任务')
              .fontSize(this.fontSize.subtitle)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.textPrimary)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })
            
            TextInput({ placeholder: '任务内容...', text: this.editTaskText })
              .onChange((value: string) => {
                this.editTaskText = value;
              })
              .width('100%')
              .height(this.isTablet ? 60 : 50)
              .borderRadius(8)
              .backgroundColor(this.colors.inputBackground)
              .placeholderColor(this.colors.textSecondary)
              .padding(16)
              .margin({ bottom: 16 })
              .fontColor(this.colors.textPrimary)
              .fontSize(this.fontSize.normal)
            
            // 截止日期选择器
            Row() {
              Text('截止日期:')
                .fontSize(this.fontSize.small)
                .fontColor(this.colors.textSecondary)
                .margin({ right: 12 })
              
              if (this.editTaskDueDate) {
                // 显示已选择的日期
                Button() {
                  Column() {
                    Row() {
                      Text(this.formatDate(this.editTaskDueDate))
                        .fontSize(this.fontSize.small)
                        .fontColor(this.colors.primary)
                      
                      Text(' ×')
                        .fontSize(this.fontSize.small)
                        .fontColor(this.colors.primary)
                        .margin({ left: 8 })
                    }
                  }
                }
                .backgroundColor(this.isDarkMode ? 'rgba(10, 132, 255, 0.2)' : 'rgba(0, 122, 255, 0.1)')
                .borderRadius(8)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.editTaskDueDate = null;
                  this.editTaskHasReminder = false;
                })
              } else {
                // 添加截止日期按钮
                Button() {
                  Column() {
                    Text('添加')
                      .fontSize(this.fontSize.small)
                      .fontColor(this.colors.primary)
                  }
                }
                .backgroundColor('transparent')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.tempSelectedDate = new Date();
                  this.showDatePicker = true;
                  
                  // 设置日期选择完成后的回调
                  this.setTempDateCallback((date: Date) => {
                    this.editTaskDueDate = date;
                  });
                })
              }
              
              Blank()
              
              // 提醒开关
              if (this.editTaskDueDate) {
                Row() {
                  Text('提醒:')
                    .fontSize(this.fontSize.small)
                    .fontColor(this.colors.textSecondary)
                    .margin({ right: 8 })
                  
                  Toggle({ type: ToggleType.Checkbox, isOn: this.editTaskHasReminder })
                    .onChange((isOn: boolean) => {
                      this.editTaskHasReminder = isOn;
                    })
                    .width(20)
                    .height(20)
                    .selectedColor(this.colors.primary)
                }
              }
            }
            .width('100%')
            .margin({ bottom: 16 })
            
            // 优先级选择
            Row() {
              Text('优先级:')
                .fontSize(this.fontSize.small)
                .fontColor(this.colors.textSecondary)
                .margin({ right: 12 })
              
              ForEach([Priority.LOW, Priority.MEDIUM, Priority.HIGH], (priority: Priority) => {
                Column() {
                  Circle()
                    .fill(this.getPriorityColor(priority))
                    .width(this.isTablet ? 20 : 16)
                    .height(this.isTablet ? 20 : 16)
                    .opacity(this.editTaskPriority === priority ? 1 : 0.5)
                    
                  Text(priority)
                    .fontSize(this.fontSize.small)
                    .fontColor(this.editTaskPriority === priority ? this.getPriorityColor(priority) : this.colors.textSecondary)
                    .fontWeight(this.editTaskPriority === priority ? FontWeight.Medium : FontWeight.Normal)
                    .margin({ top: 8 })
                }
                .padding(12)
                .borderRadius(8)
                .backgroundColor(this.editTaskPriority === priority ? (this.isDarkMode ? '#2C2C2E' : '#F2F2F7') : 'transparent')
                .margin({ right: 16 })
                .onClick(() => {
                  this.editTaskPriority = priority;
                })
              })
            }
            .width('100%')
            .margin({ bottom: 16 })
            
            // 按钮行
            Row() {
              Button() {
                Column() {
                  Text('取消')
                    .fontSize(this.fontSize.normal)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.textSecondary)
                }
              }
              .backgroundColor('transparent')
              .margin({ right: 16 })
              .onClick(() => {
                this.cancelEditTask();
              })
              
              Blank()
              
              Button() {
                Column() {
                  Text('保存')
                    .fontSize(this.fontSize.normal)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                }
              }
              .backgroundColor(this.colors.primary)
              .borderRadius(8)
              .padding({ left: 16, right: 16, top: this.isTablet ? 8 : 4, bottom: this.isTablet ? 8 : 4 })
              .enabled(this.editTaskText.trim() !== '')
              .opacity(this.editTaskText.trim() !== '' ? 1 : 0.5)
              .onClick(() => {
                this.saveEditTask();
              })
            }
            .width('100%')
          }
          .width(this.contentMaxWidth)
          .padding(16)
          .backgroundColor(this.isDarkMode ? '#2C2C2E' : '#F2F2F7')
          .borderRadius(12)
          .margin({ bottom: 20 })
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
        }
      }
      .width(this.isLandscape && this.isTablet ? '70%' : '100%')
      .height('100%')
      .backgroundColor(this.colors.background)
    }
    .width('100%')
    .height('100%')
  }
}

// Todo item component
@Component
struct TodoItemComponent {
  item: TodoItem = new TodoItem('');
  onDelete: () => void = () => {};
  onToggleComplete: () => void = () => {};
  onEdit: (item: TodoItem) => void = () => {};
  animationDelay: number = 0;
  isTablet: boolean = false;
  fontSize: FontSizeConfig = { title: 34, subtitle: 18, normal: 16, small: 14 };
  colors: ThemeColors = AppTheme.LIGHT;
  isDarkMode: boolean = false;
  @State isSwipedLeft: boolean = false;
  @State isSwipedRight: boolean = false;
  @State isAnimated: boolean = false;
  @State isPressed: boolean = false;

  aboutToAppear() {
    // 组件出现时触发动画
    setTimeout(() => {
      this.isAnimated = true;
    }, this.animationDelay);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Delete button (revealed when swiped)
      Row() {
        Blank()
        Button() {
          Column() {
            Text('删除')
              .fontSize(this.fontSize.small)
              .fontColor('#FFFFFF')
          }
        }
        .height('100%')
        .backgroundColor(this.colors.priorityHigh)
        .borderRadius(12)
        .width(this.isTablet ? 100 : 80)
        .onClick(() => {
          this.vibrateShort();
          this.onDelete();
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.isSwipedLeft ? Visibility.Visible : Visibility.Hidden)
      
      // Complete button (revealed when swiped right)
      Row() {
        Button() {
          Column() {
            Text(this.item.isCompleted ? '未完成' : '完成')
              .fontSize(this.fontSize.small)
              .fontColor('#FFFFFF')
          }
        }
        .height('100%')
        .backgroundColor(this.colors.priorityLow)
        .borderRadius(12)
        .width(this.isTablet ? 100 : 80)
        .onClick(() => {
          this.vibrateShort();
          this.onToggleComplete();
        })
        
        Blank()
      }
      .width('100%')
      .height('100%')
      .visibility(this.isSwipedRight ? Visibility.Visible : Visibility.Hidden)
      
      // 拖动提示
      if (!this.isSwipedLeft && !this.isSwipedRight) {
        Row() {
          Text(this.isPressed ? '左滑删除 · 右滑完成 · 长按编辑' : '')
            .fontSize(12)
            .fontColor(this.colors.textSecondary)
            .opacity(0.7)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.colors.background)
        .position({ x: 0, y: 0 })
        .zIndex(1)
        .opacity(this.isPressed ? 0.9 : 0)
        .animation({
          duration: 200,
          curve: Curve.EaseOut
        })
      }
      
      // Todo item card
      Column() {
        Row() {
          // Custom checkbox
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(this.isTablet ? 28 : 24)
              .height(this.isTablet ? 28 : 24)
              .fill(this.item.isCompleted ? this.colors.primary : this.colors.cardBackground)
              .stroke(this.item.isCompleted ? this.colors.primary : this.colors.textDisabled)
              .strokeWidth(2)
              
            if (this.item.isCompleted) {
              Text('✓')
                .fontSize(this.isTablet ? 18 : 16)
                .fontColor('#FFFFFF')
            }
          }
          .width(this.isTablet ? 28 : 24)
          .height(this.isTablet ? 28 : 24)
          .margin({ right: 16 })
          .onClick(() => {
            this.onToggleComplete();
          })

          Column() {
            Text(this.item.text)
              .fontSize(this.isTablet ? 18 : 17)
              .fontColor(this.item.isCompleted ? this.colors.textSecondary : this.colors.textPrimary)
              .decoration({ type: this.item.isCompleted ? TextDecorationType.LineThrough : TextDecorationType.None })
              .width('100%')
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(2)

            Row() {
              // Priority indicator
              Circle()
                .width(8)
                .height(8)
                .fill(this.getPriorityColor(this.item.priority))
                .margin({ right: 6 })
                
              Text(this.item.priority)
                .fontSize(this.fontSize.small)
                .fontColor(this.colors.textSecondary)
                .margin({ right: 12 })
                
              // 截止日期
              if (this.item.dueDate) {
                Row() {
                  // 日历图标
                  Text('📅')
                    .fontSize(12)
                    .margin({ right: 4 })
                  
                  // 日期文本
                  Text(this.formatDate(this.item.dueDate))
                    .fontSize(this.fontSize.small)
                    .fontColor(this.item.isOverdue() ? this.colors.priorityHigh : 
                              (this.item.isComingSoon() ? this.colors.priorityMedium : this.colors.textSecondary))
                    .fontWeight(this.item.isOverdue() || this.item.isComingSoon() ? FontWeight.Medium : FontWeight.Normal)
                }
                .margin({ right: 12 })
              }
              
              // 提醒图标
              if (this.item.hasReminder) {
                Text('🔔')
                  .fontSize(12)
                  .margin({ right: 8 })
              }
              
              // Date
              Text(this.formatDate(this.item.createdAt))
                .fontSize(this.fontSize.small)
                .fontColor(this.colors.textSecondary)
            }
            .margin({ top: 6 })
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
      .padding(this.isTablet ? 20 : 16)
      .backgroundColor(this.colors.cardBackground)
      .borderRadius(12)
      .shadow({ radius: 1, color: this.colors.cardBorder, offsetX: 0, offsetY: 1 })
      .translate({ 
        x: this.isSwipedLeft ? 
           (this.isTablet ? -100 : -80) : 
           (this.isSwipedRight ? (this.isTablet ? 100 : 80) : 0) 
      })
      .opacity(this.isPressed ? 0.8 : 1)
      .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
      .animation({ 
        duration: 200, 
        curve: Curve.EaseOut 
      })
      .gesture(
        GestureGroup(GestureMode.Parallel,
          SwipeGesture({ direction: SwipeDirection.Horizontal })
            .onAction((event: GestureEvent) => {
              if (event.offsetX < -20) {
                this.isSwipedLeft = true;
                this.isSwipedRight = false;
                this.vibrateShort();
              } else if (event.offsetX > 20) {
                this.isSwipedRight = true;
                this.isSwipedLeft = false;
                this.vibrateShort();
              }
            }),
          TapGesture()
            .onAction(() => {
              if (this.isSwipedLeft || this.isSwipedRight) {
                this.isSwipedLeft = false;
                this.isSwipedRight = false;
              }
            }),
          LongPressGesture()
            .onAction(() => {
              this.vibrateShort();
              if (this.onEdit) {
                this.onEdit(this.item);
              }
            })
            .onActionCancel(() => {
              this.isPressed = true;
            })
            .onActionEnd(() => {
              this.isPressed = false;
            })
        )
      )
    }
    .height(this.item.text.length > 30 ? 'auto' : (this.isTablet ? 88 : 76))
    .clip(true)
    .opacity(this.isAnimated ? 1 : 0)
    .animation({
      duration: 300,
      curve: Curve.EaseOut,
      delay: this.animationDelay,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  private formatDate(date: Date | null): string {
    if (!date) return '';
    
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(now.getDate() + 1);
    
    if (date.getDate() === now.getDate() && 
        date.getMonth() === now.getMonth() && 
        date.getFullYear() === now.getFullYear()) {
      return '今天';
    } else if (date.getDate() === tomorrow.getDate() && 
               date.getMonth() === tomorrow.getMonth() && 
               date.getFullYear() === tomorrow.getFullYear()) {
      return '明天';
    } else {
      return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
    }
  }

  private getPriorityColor(priority: Priority): string {
    switch (priority) {
      case Priority.HIGH:
        return this.colors.priorityHigh;
      case Priority.MEDIUM:
        return this.colors.priorityMedium;
      case Priority.LOW:
        return this.colors.priorityLow;
      default:
        return this.colors.textSecondary;
    }
  }

  // 判断任务是否即将到期
  private isComingSoon(): boolean {
    if (!this.item.dueDate) return false;
    
    return this.item.isComingSoon();
  }
  
  // 判断任务是否已过期
  private isOverdue(): boolean {
    if (!this.item.dueDate) return false;
    
    return this.item.isOverdue();
  }

  // 短振动
  private vibrateShort() {
    try {
      // Vibración corta de 10ms
      vibrator.vibrate(10);
    } catch (error) {
      console.error('Failed to vibrate:', error);
    }
  }
}

// Todo item class
class TodoItem {
  id: number;
  text: string;
  isCompleted: boolean;
  createdAt: Date;
  priority: Priority;
  dueDate: Date | null;  // 截止日期
  hasReminder: boolean;  // 是否有提醒

  constructor(text: string, priority: Priority = Priority.MEDIUM, dueDate: Date | null = null, hasReminder: boolean = false) {
    this.id = Date.now();
    this.text = text;
    this.isCompleted = false;
    this.createdAt = new Date();
    this.priority = priority;
    this.dueDate = dueDate;
    this.hasReminder = hasReminder;
  }
  
  // 检查任务是否即将到期（24小时内）
  isComingSoon(): boolean {
    if (!this.dueDate) return false;
    
    const now = new Date();
    const diff = this.dueDate.getTime() - now.getTime();
    const oneDay = 24 * 60 * 60 * 1000;
    
    return diff > 0 && diff < oneDay;
  }
  
  // 检查任务是否已过期
  isOverdue(): boolean {
    if (!this.dueDate) return false;
    
    const now = new Date();
    return this.dueDate.getTime() < now.getTime();
  }
}
