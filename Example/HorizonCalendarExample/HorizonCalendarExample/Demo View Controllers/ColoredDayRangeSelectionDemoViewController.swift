import HorizonCalendar
import UIKit

final class ColoredDayRangeSelectionDemoViewController: BaseDemoViewController {

    // MARK: Private Properties

    /// The currently selected date range.
    private var selectedDayRange: DayComponentsRange?

    /// The snapshot of the range when a drag begins.
    private var selectedDayRangeAtStartOfDrag: DayComponentsRange?
    
    /// The color chosen by the user for the finalized range.
    private var selectedRangeColor: UIColor?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Day Range Selection"

        calendarView.daySelectionHandler = { [weak self] day in
            guard let self = self else { return }

            // Update the selected range using our helper.
            DayRangeSelectionHelper.updateDayRange(
                afterTapSelectionOf: day,
                existingDayRange: &self.selectedDayRange
            )

            // If the range is complete (both boundaries exist) then prompt for a color.
            if let range = self.selectedDayRange,
               let lowerBound = self.calendar.date(from: range.lowerBound.components),
               let upperBound = self.calendar.date(from: range.upperBound.components) {
                self.presentColorPicker { chosenColor in
                    self.selectedRangeColor = chosenColor
                    // The color is now associated with the selected range.
                    self.calendarView.setContent(self.makeContent())
                }
            } else {
                self.calendarView.setContent(self.makeContent())
            }
        }

        calendarView.multiDaySelectionDragHandler = { [weak self, calendar] day, state in
            guard let self = self else { return }

            // Update the selected range during the drag.
            DayRangeSelectionHelper.updateDayRange(
                afterDragSelectionOf: day,
                existingDayRange: &self.selectedDayRange,
                initialDayRange: &self.selectedDayRangeAtStartOfDrag,
                state: state,
                calendar: calendar
            )

            // When the drag ends, if the range is complete, prompt for a color.
            if state == .ended,
               let range = self.selectedDayRange,
               let lowerBound = self.calendar.date(from: range.lowerBound.components),
               let upperBound = self.calendar.date(from: range.upperBound.components) {
                self.presentColorPicker { chosenColor in
                    self.selectedRangeColor = chosenColor
                    self.calendarView.setContent(self.makeContent())
                }
            } else {
                self.calendarView.setContent(self.makeContent())
            }
        }
    }

    override func makeContent() -> CalendarViewContent {
        // Use the original visible date range (for example purposes).
        let startDate = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2021, month: 12, day: 31))!

        // Compute the date range (if the user has finalized a range).
        let dateRanges: Set<ClosedRange<Date>>
        if let range = selectedDayRange,
           let lowerBound = calendar.date(from: range.lowerBound.components),
           let upperBound = calendar.date(from: range.upperBound.components) {
            dateRanges = [lowerBound ... upperBound]
        } else {
            dateRanges = []
        }

        return CalendarViewContent(
            calendar: calendar,
            visibleDateRange: startDate ... endDate,
            monthsLayout: monthsLayout
        )
        .interMonthSpacing(24)
        .verticalDayMargin(8)
        .horizontalDayMargin(8)
        .dayItemProvider { [unowned self, calendar, dayDateFormatter] day in
            var invariantViewProperties = DayView.InvariantViewProperties.baseInteractive

            let date = calendar.date(from: day.components)
            
            // If a color has been chosen and a range exists, highlight every day within the range.
            if let range = self.selectedDayRange,
               let lowerBound = calendar.date(from: range.lowerBound.components),
               let upperBound = calendar.date(from: range.upperBound.components),
               let currentDate = date {
                if currentDate >= lowerBound && currentDate <= upperBound {
                    let color = self.selectedRangeColor ?? UIColor(.accentColor)
                    // Fill all days within the range with a semi-transparent color.
                    invariantViewProperties.backgroundShapeDrawingConfig.fillColor = color.withAlphaComponent(0.15)
                    // If the current day is at the start or end, add a border.
                    if currentDate == lowerBound || currentDate == upperBound {
                        invariantViewProperties.backgroundShapeDrawingConfig.borderColor = color
                    }
                }
            }

            return DayView.calendarItemModel(
                invariantViewProperties: invariantViewProperties,
                content: .init(
                    dayText: "\(day.day)",
                    accessibilityLabel: date.map { dayDateFormatter.string(from: $0) },
                    accessibilityHint: nil
                )
            )
        }
        .dayRangeItemProvider(for: dateRanges) { dayRangeLayoutContext in
            // This remains unchanged. It overlays the selected range.
            DayRangeIndicatorView.calendarItemModel(
                invariantViewProperties: .init(),
                content: .init(
                    framesOfDaysToHighlight: dayRangeLayoutContext.daysAndFrames.map(\.frame)
                )
            )
        }
    }

    // MARK: - Private Methods

    /// Presents a color picker (action sheet) for the user to choose a color.
    private func presentColorPicker(completion: @escaping (UIColor) -> Void) {
        let alert = UIAlertController(title: "Select a Color",
                                      message: "Choose a color for this range",
                                      preferredStyle: .actionSheet)
        let colorOptions: [(name: String, color: UIColor)] = [
            ("Red", .systemRed),
            ("Green", .systemGreen),
            ("Blue", .systemBlue),
            ("Orange", .systemOrange),
            ("Purple", .systemPurple),
            ("Teal", .systemTeal)
        ]
        for option in colorOptions {
            alert.addAction(UIAlertAction(title: option.name, style: .default) { _ in
                completion(option.color)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
