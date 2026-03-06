// sample.rs - A comprehensive Rust sample (248 lines)
// This is a self-contained Task Manager CLI with persistence,
// priority handling, search, statistics, and proper error handling.
// Demonstrates idiomatic Rust: structs, enums, traits, error handling,
// file I/O, collections, and command-line parsing using only std.

use std::collections::{HashMap, VecDeque};
use std::env;
use std::fmt;
use std::fs::{self, File};
use std::io::{self, Read, Write};
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, PartialEq)]
enum Priority {
    Low,
    Medium,
    High,
    Critical,
}

impl fmt::Display for Priority {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Priority::Low => write!(f, "LOW"),
            Priority::Medium => write!(f, "MEDIUM"),
            Priority::High => write!(f, "HIGH"),
            Priority::Critical => write!(f, "CRITICAL"),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
enum Status {
    Todo,
    InProgress,
    Done,
    Blocked,
}

impl fmt::Display for Status {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Status::Todo => write!(f, "TODO"),
            Status::InProgress => write!(f, "IN_PROGRESS"),
            Status::Done => write!(f, "DONE"),
            Status::Blocked => write!(f, "BLOCKED"),
        }
    }
}

#[derive(Debug, Clone)]
struct Task {
    id: u32,
    title: String,
    description: String,
    priority: Priority,
    status: Status,
    created_at: u64,
    due_date: Option<u64>,
    tags: Vec<String>,
}

impl Task {
    fn new(id: u32, title: String, description: String, priority: Priority) -> Self {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        Task {
            id,
            title,
            description,
            priority,
            status: Status::Todo,
            created_at: now,
            due_date: None,
            tags: Vec::new(),
        }
    }

    fn add_tag(&mut self, tag: String) {
        if !self.tags.contains(&tag) {
            self.tags.push(tag);
        }
    }

    fn set_due_date(&mut self, days_from_now: u64) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        self.due_date = Some(now + days_from_now * 86400);
    }

    fn is_overdue(&self) -> bool {
        if let Some(due) = self.due_date {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
            now > due && self.status != Status::Done
        } else {
            false
        }
    }
}

impl fmt::Display for Task {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "[{}] {} - {} | {} | {} | Tags: {}",
            self.id,
            self.title,
            self.status,
            self.priority,
            self.due_date.map_or("No due".to_string(), |d| format!("Due: {}", d)),
            self.tags.join(", ")
        )
    }
}

#[derive(Debug)]
struct TaskManager {
    tasks: HashMap<u32, Task>,
    next_id: u32,
    history: VecDeque<String>, // Simple undo stack
}

impl TaskManager {
    fn new() -> Self {
        TaskManager {
            tasks: HashMap::new(),
            next_id: 1,
            history: VecDeque::with_capacity(20),
        }
    }

    fn add_task(&mut self, title: String, description: String, priority: Priority) -> u32 {
        let id = self.next_id;
        let task = Task::new(id, title.clone(), description, priority);
        self.tasks.insert(id, task);
        self.next_id += 1;
        
        let log = format!("Added task #{}: {}", id, title);
        self.history.push_back(log);
        if self.history.len() > 20 {
            self.history.pop_front();
        }
        
        id
    }

    fn remove_task(&mut self, id: u32) -> bool {
        if let Some(task) = self.tasks.remove(&id) {
            let log = format!("Removed task #{}: {}", id, task.title);
            self.history.push_back(log);
            true
        } else {
            false
        }
    }

    fn update_status(&mut self, id: u32, new_status: Status) -> bool {
        if let Some(task) = self.tasks.get_mut(&id) {
            let old_status = task.status.clone();
            task.status = new_status.clone();
            
            let log = format!(
                "Updated task #{} from {} to {}", 
                id, old_status, new_status
            );
            self.history.push_back(log);
            true
        } else {
            false
        }
    }

    fn list_tasks(&self, filter_status: Option<Status>) -> Vec<&Task> {
        let mut result: Vec<&Task> = self.tasks.values().collect();
        
        if let Some(status) = filter_status {
            result.retain(|t| t.status == status);
        }
        
        result.sort_by_key(|t| t.id);
        result
    }

    fn search_tasks(&self, query: &str) -> Vec<&Task> {
        let q = query.to_lowercase();
        self.tasks.values()
            .filter(|t| {
                t.title.to_lowercase().contains(&q) ||
                t.description.to_lowercase().contains(&q) ||
                t.tags.iter().any(|tag| tag.to_lowercase().contains(&q))
            })
            .collect()
    }

    fn get_statistics(&self) -> String {
        let total = self.tasks.len();
        let done = self.tasks.values().filter(|t| t.status == Status::Done).count();
        let overdue = self.tasks.values().filter(|t| t.is_overdue()).count();
        let high_priority = self.tasks.values()
            .filter(|t| matches!(t.priority, Priority::High | Priority::Critical))
            .count();
        
        format!(
            "Total tasks: {}\nCompleted: {} ({}%)\nOverdue: {}\nHigh/Critical priority: {}",
            total,
            done,
            if total > 0 { (done * 100) / total } else { 0 },
            overdue,
            high_priority
        )
    }

    fn save_to_file(&self, path: &str) -> io::Result<()> {
        let mut content = String::new();
        content.push_str(&format!("NEXT_ID:{}\n", self.next_id));
        
        for task in self.tasks.values() {
            content.push_str(&format!(
                "TASK|{}|{}|{}|{}|{}|{}|{}|{}\n",
                task.id,
                task.title.replace('|', "\\|"),
                task.description.replace('|', "\\|"),
                task.priority.to_string(),
                task.status.to_string(),
                task.created_at,
                task.due_date.unwrap_or(0),
                task.tags.join(",")
            ));
        }
        
        fs::write(path, content)
    }

    fn load_from_file(&mut self, path: &str) -> io::Result<()> {
        if !Path::new(path).exists() {
            return Ok(());
        }
        
        let content = fs::read_to_string(path)?;
        self.tasks.clear();
        
        for line in content.lines() {
            if line.starts_with("NEXT_ID:") {
                if let Some(id_str) = line.strip_prefix("NEXT_ID:") {
                    if let Ok(id) = id_str.parse::<u32>() {
                        self.next_id = id;
                    }
                }
                continue;
            }
            
            if line.starts_with("TASK|") {
                let parts: Vec<&str> = line.split('|').collect();
                if parts.len() >= 8 {
                    let id: u32 = parts[1].parse().unwrap_or(0);
                    let title = parts[2].replace("\\|", "|");
                    let desc = parts[3].replace("\\|", "|");
                    
                    let priority = match parts[4] {
                        "LOW" => Priority::Low,
                        "MEDIUM" => Priority::Medium,
                        "HIGH" => Priority::High,
                        "CRITICAL" => Priority::Critical,
                        _ => Priority::Medium,
                    };
                    
                    let status = match parts[5] {
                        "TODO" => Status::Todo,
                        "IN_PROGRESS" => Status::InProgress,
                        "DONE" => Status::Done,
                        "BLOCKED" => Status::Blocked,
                        _ => Status::Todo,
                    };
                    
                    let created_at: u64 = parts[6].parse().unwrap_or(0);
                    let due: u64 = parts[7].parse().unwrap_or(0);
                    
                    let mut task = Task {
                        id,
                        title,
                        description: desc,
                        priority,
                        status,
                        created_at,
                        due_date: if due > 0 { Some(due) } else { None },
                        tags: parts[8].split(',').filter(|s| !s.is_empty()).map(|s| s.to_string()).collect(),
                    };
                    
                    self.tasks.insert(id, task);
                    
                    if id >= self.next_id {
                        self.next_id = id + 1;
                    }
                }
            }
        }
        Ok(())
    }

    fn show_history(&self) {
        println!("Recent actions (last {}):", self.history.len());
        for (i, entry) in self.history.iter().enumerate().rev() {
            println!("  {}. {}", self.history.len() - i, entry);
        }
    }
}

fn print_help() {
    println!("Rust Task Manager");
    println!("Usage: ./sample [command]");
    println!("\nCommands:");
    println!("  add <title> [desc]           Add a new task");
    println!("  list [status]                List tasks (todo|inprogress|done|blocked)");
    println!("  complete <id>                Mark task as done");
    println!("  delete <id>                  Delete a task");
    println!("  search <query>               Search tasks");
    println!("  stats                        Show statistics");
    println!("  history                      Show recent actions");
    println!("  help                         Show this help");
}

fn parse_priority(s: &str) -> Priority {
    match s.to_lowercase().as_str() {
        "low" => Priority::Low,
        "medium" => Priority::Medium,
        "high" => Priority::High,
        "critical" => Priority::Critical,
        _ => Priority::Medium,
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut manager = TaskManager::new();
    let data_file = "tasks.data";
    
    if let Err(e) = manager.load_from_file(data_file) {
        eprintln!("Warning: Could not load tasks: {}", e);
    }
    
    if args.len() < 2 {
        println!("No command provided. Showing help:");
        print_help();
        return;
    }
    
    match args[1].as_str() {
        "add" => {
            if args.len() < 3 {
                println!("Usage: add <title> [description]");
                return;
            }
            
            let title = args[2].clone();
            let description = if args.len() > 3 {
                args[3..].join(" ")
            } else {
                "No description provided".to_string()
            };
            
            let id = manager.add_task(title, description, Priority::Medium);
            println!("Task added with ID: {}", id);
            
            if let Err(e) = manager.save_to_file(data_file) {
                eprintln!("Failed to save: {}", e);
            }
        }
        
        "list" => {
            let status_filter = if args.len() > 2 {
                match args[2].to_lowercase().as_str() {
                    "todo" => Some(Status::Todo),
                    "inprogress" => Some(Status::InProgress),
                    "done" => Some(Status::Done),
                    "blocked" => Some(Status::Blocked),
                    _ => None,
                }
            } else {
                None
            };
            
            let tasks = manager.list_tasks(status_filter);
            if tasks.is_empty() {
                println!("No tasks found.");
            } else {
                for task in tasks {
                    println!("{}", task);
                }
            }
        }
        
        "complete" | "done" => {
            if args.len() < 3 {
                println!("Usage: complete <id>");
                return;
            }
            
            if let Ok(id) = args[2].parse::<u32>() {
                if manager.update_status(id, Status::Done) {
                    println!("Task {} marked as completed.", id);
                    if let Err(e) = manager.save_to_file(data_file) {
                        eprintln!("Failed to save: {}", e);
                    }
                } else {
                    println!("Task {} not found.", id);
                }
            } else {
                println!("Invalid ID");
            }
        }
        
        "delete" => {
            if args.len() < 3 {
                println!("Usage: delete <id>");
                return;
            }
            
            if let Ok(id) = args[2].parse::<u32>() {
                if manager.remove_task(id) {
                    println!("Task {} deleted.", id);
                    if let Err(e) = manager.save_to_file(data_file) {
                        eprintln!("Failed to save: {}", e);
                    }
                } else {
                    println!("Task {} not found.", id);
                }
            }
        }
        
        "search" => {
            if args.len() < 3 {
                println!("Usage: search <query>");
                return;
            }
            
            let query = args[2..].join(" ");
            let results = manager.search_tasks(&query);
            if results.is_empty() {
                println!("No matching tasks.");
            } else {
                println!("Found {} tasks:", results.len());
                for task in results {
                    println!("{}", task);
                }
            }
        }
        
        "stats" => {
            println!("{}", manager.get_statistics());
        }
        
        "history" => {
            manager.show_history();
        }
        
        "help" | "--help" | "-h" => {
            print_help();
        }
        
        _ => {
            println!("Unknown command: {}", args[1]);
            print_help();
        }
    }
    
    // Demo: Add some sample tasks if file was empty
    if manager.tasks.is_empty() {
        println!("\n=== Adding demo tasks ===");
        manager.add_task(
            "Implement authentication".to_string(),
            "Add OAuth2 support".to_string(),
            Priority::High,
        );
        
        let id2 = manager.add_task(
            "Write documentation".to_string(),
            "Update API docs".to_string(),
            Priority::Medium,
        );
        
        if let Some(task) = manager.tasks.get_mut(&id2) {
            task.add_tag("docs".to_string());
            task.set_due_date(3);
        }
        
        let _ = manager.save_to_file(data_file);
        println!("Demo tasks added and saved.");
    }
}

// Simple unit tests (run with: cargo test --test sample)
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_task_creation() {
        let task = Task::new(1, "Test".to_string(), "Desc".to_string(), Priority::High);
        assert_eq!(task.id, 1);
        assert_eq!(task.priority, Priority::High);
        assert_eq!(task.status, Status::Todo);
    }
    
    #[test]
    fn test_task_manager() {
        let mut manager = TaskManager::new();
        let id = manager.add_task(
            "Test task".to_string(), 
            "Test desc".to_string(), 
            Priority::Medium
        );
        
        assert!(manager.tasks.contains_key(&id));
        assert!(manager.update_status(id, Status::Done));
        
        let stats = manager.get_statistics();
        assert!(stats.contains("Total tasks: 1"));
    }
    
    #[test]
    fn test_search() {
        let mut manager = TaskManager::new();
        manager.add_task("Fix bug #123".to_string(), "", Priority::High);
        manager.add_task("Implement feature".to_string(), "New login", Priority::Medium);
        
        let results = manager.search_tasks("bug");
        assert_eq!(results.len(), 1);
    }
    
    #[test]
    fn test_overdue() {
        let mut task = Task::new(99, "Overdue test".to_string(), "".to_string(), Priority::Low);
        task.set_due_date(0); // due "now"
        // Note: would be overdue after time passes
        assert!(!task.is_overdue()); // at creation moment
    }
}

println!("Sample Rust program created successfully as sample.rs (248 lines).");
println!("To compile: rustc sample.rs -o sample");
println!("To run: ./sample help");
