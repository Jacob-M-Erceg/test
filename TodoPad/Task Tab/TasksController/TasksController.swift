//
//  TasksController.swift
//  TodoPad
//
//  Created by John Lee on 2022-08-02.
//

import UIKit

protocol TasksControllerDelegate: AnyObject {
    func showTaskCompletedPopup()
}

class TasksController: UIViewController {
    
    // MARK: - Variables
    let viewModel: TasksControllerViewModel
    
    weak var delegate: TasksControllerDelegate?
    
    // MARK: - UI Components
    let dateScroller: DateScroller
    
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(TaskGroupCell.self, forHeaderFooterViewReuseIdentifier: TaskGroupCell.identifier)
        tableView.register(TaskCell.self, forCellReuseIdentifier: TaskCell.identifier)
        tableView.backgroundColor = .dynamicColorOne
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 66, right: 0)
        return tableView
    }()
    
    // MARK: - Lifecycle
    init(_ dateScroller: DateScroller = DateScroller(), viewModel: TasksControllerViewModel = TasksControllerViewModel()) {
        self.dateScroller = dateScroller
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DateHelper.getMonthAndDayString(for: Date())
        self.setupUI()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.dateScroller.delegate = self
        
        self.viewModel.onUpdate = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
        
        self.viewModel.onExpandCloseGroup = { [weak self] indexPaths, isOpening in
            DispatchQueue.main.async { [weak self] in
                self?.tableView.performBatchUpdates({
                    if isOpening {
                        self?.tableView.insertRows(at: indexPaths, with: .fade)
                    } else {
                        self?.tableView.deleteRows(at: indexPaths, with: .fade)
                    }
                }, completion: { [weak self] _ in
                    self?.tableView.reloadData()
                })
            }
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(didTapSettings))
    }
    
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .dynamicColorOne
        
        view.addSubview(dateScroller)
        view.addSubview(tableView)
        
        dateScroller.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            dateScroller.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            dateScroller.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            dateScroller.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            dateScroller.heightAnchor.constraint(equalToConstant: 88),
            
            tableView.topAnchor.constraint(equalTo: dateScroller.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        let header = TasksTableViewHeader(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 66))
        header.delegate = self
        tableView.tableHeaderView = header
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0.0 }
    }
    
    @objc private func didTapSettings() {
        HapticsManager.shared.vibrateForSelection()
        
        let vc = SettingsController()
        vc.refreshTasks = { [weak self] in
            self?.viewModel.fetchTasks(for: self?.viewModel.selectedDate ?? Date())
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
}


// MARK: - DateScroller Delegate Functions
extension TasksController: DateScrollerDelegate {
    
    func didChangeDate(with date: Date) {
        self.navigationItem.title = DateHelper.getMonthAndDayString(for: date)
        self.viewModel.changeSelectedDate(with: date)
        HapticsManager.shared.vibrateForSelection()
    }
}


// MARK: - TableView - Cell Headers
extension TasksController: UITableViewDelegate, UITableViewDataSource, TaskGroupCellDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.viewModel.taskGroups.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TaskGroupCell.identifier) as? TaskGroupCell else {
            return UITableViewHeaderFooterView()
        }
        let taskGroup = self.viewModel.taskGroups[section]
        header.configure(with: taskGroup)
        header.delegate = self
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    func didTapTaskGroupCell(for taskGroup: TaskGroup) {
        HapticsManager.shared.vibrateForSelection()
        self.viewModel.openOrCloseTaskGroupSection(for: taskGroup)
    }
}


// MARK: - TableView - Main
extension TasksController {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let taskGroup = self.viewModel.taskGroups[section]
        return taskGroup.isOpened ? taskGroup.tasks.count : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TaskCell.identifier, for: indexPath) as? TaskCell else {
            fatalError("Failed to dequeueReusableCell in TasksController.")
        }
        let task = self.viewModel.taskGroups[indexPath.section].tasks[indexPath.row]
        let isCompleted = task.isCompleted
        cell.configure(with: task, isCompleted)

        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 66
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        HapticsManager.shared.vibrateForSelection()
        
        let task = self.viewModel.taskGroups[indexPath.section].tasks[indexPath.row]
        let viewModel = ViewTaskControllerViewModel(task: task)
        let vc = ViewTaskController(viewModel: viewModel)
        vc.onTappedCompleteTask = { [weak self] in
            self?.viewModel.invertTaskCompleted(with: task)
            if !task.isCompleted {
                self?.showTaskCompletedPopup()
            }
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.setupNavBarColor()
        self.present(nav, animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let task = self.viewModel.taskGroups[indexPath.section].tasks[indexPath.row]
        let isCompleted = self.viewModel.isTaskCompleted(with: task)
        
        let actionButtonTitle: String = isCompleted ? "Undo" : "Complete"
        
        let action = UIContextualAction(style: .normal, title: actionButtonTitle) { [weak self] _, _, completion in
            guard let self = self else { return }
            HapticsManager.shared.vibrateForActionCompleted()
            
            self.viewModel.invertTaskCompleted(with: task)
            if !isCompleted {
                self.showTaskCompletedPopup()
            }
        }
        action.backgroundColor = .systemBlue
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, _ in
            guard let self = self else { return }
            HapticsManager.shared.vibrateForSelection()
            let task = self.viewModel.taskGroups[indexPath.section].tasks[indexPath.row]
            self.didTapEditTask(for: task)
        }

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, _ in
            guard let self = self else { return }
            HapticsManager.shared.vibrateForSelection()
            let task = self.viewModel.taskGroups[indexPath.section].tasks[indexPath.row]
            self.deleteTask(with: task)
        }
        return UISwipeActionsConfiguration(actions: [delete, edit])
    }
}


// MARK: - Add/Edit Tasks
extension TasksController: TasksTableViewHeaderDelegate {
    
    func didTapAddNewTask() {
        HapticsManager.shared.vibrateForSelection()
        
        let taskFormModel = TaskFormModel()
        let viewModel = TaskFormControllerViewModel(selectedDate: self.viewModel.selectedDate, taskFormModel: taskFormModel, originalTask: nil)
        let vc = TaskFormController(viewModel)
        vc.onCompleted = { [weak self] in
            guard let self = self else { return }
            self.viewModel.fetchTasks(for: self.viewModel.selectedDate)
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func didTapEditTask(for task: Task) {
        var taskFormModel: TaskFormModel
        
        switch task {
        case .persistent(let persistentTask):
            taskFormModel = TaskFormModel(for: persistentTask)
            
        case .repeating(let repeatingTask):
            taskFormModel = TaskFormModel(for: repeatingTask)
            
        case .nonRepeating(let nonRepeatingTask):
            taskFormModel = TaskFormModel(for: nonRepeatingTask)
        }
        
        let viewModel = TaskFormControllerViewModel(selectedDate: self.viewModel.selectedDate, taskFormModel: taskFormModel, originalTask: task)
        let vc = TaskFormController(viewModel)
        
        vc.onCompleted = { [weak self] in
            guard let self = self else { return }
            self.viewModel.fetchTasks(for: self.viewModel.selectedDate)
        }
        
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Delete Tasks
extension TasksController {
    
    private func deleteTask(with task: Task) {
        switch task {
        case .persistent(_), .nonRepeating(_):
            AlertManager.showDeleteTaskWarning(on: self) { [weak self] willContinue in
                guard willContinue else { self?.viewModel.onUpdate?(); return }
                self?.viewModel.deleteTask(for: task)
                HapticsManager.shared.vibrateForActionCompleted()
            }
            
            return
        case .repeating(let repeatingTask):
            self.deleteRepeatingTask(for: repeatingTask)
        }
    }
    
    private func deleteRepeatingTask(for repeatingTask: RepeatingTask) {
        AlertManager.showDeleteRepeatingTaskAlert(on: self) { [weak self] selectionOption in
            guard let self = self else { return }
            switch selectionOption {
            case .allFuture:
                HapticsManager.shared.vibrateForActionCompleted()
                
                self.viewModel.deleteRepeatingTaskForThisAndFutureDays(for: repeatingTask, selectedDate: self.viewModel.selectedDate)
                break
                
            case .allTasks:
                HapticsManager.shared.vibrateForSelection()
                
                AlertManager.showCompletelyDeleteRepeatingTaskWarning(on: self) { [weak self] willContinue in
                    if willContinue {
                        HapticsManager.shared.vibrateForActionCompleted()
                        self?.viewModel.completelyDeleteRepeatingTask(for: repeatingTask)
                    } else {
                        HapticsManager.shared.vibrateForSelection()
                        self?.viewModel.onUpdate?()
                    }
                }
            case .cancel:
                return
            }
        }
    }
}


// MARK: - Show Task Completed Popup
extension TasksController {
    
    private func showTaskCompletedPopup() {
        self.delegate?.showTaskCompletedPopup()
    }
}
