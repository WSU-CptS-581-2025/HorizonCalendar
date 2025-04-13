//
//  CalendarViewAccessibility.swift
//  HorizonCalendar
//
//  Created by Kyle Parker on 4/13/25.
//  Copyright © 2025 Airbnb. All rights reserved.
//

import UIKit

// MARK: UIAccessibility

extension CalendarView {
    // MARK: Public

    public override var isAccessibilityElement: Bool {
        get { false }
        set {}
    }

    public override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard
            let firstVisibleMonth = visibleMonthRange?.lowerBound,
            let lastVisibleMonth = visibleMonthRange?.upperBound,
            let firstVisibleMonthDate = calendar.date(from: firstVisibleMonth.components),
            let lastVisibleMonthDate = calendar.date(from: lastVisibleMonth.components),
            let numberOfVisibleMonths = calendar.dateComponents(
                [.month],
                from: firstVisibleMonthDate,
                to: lastVisibleMonthDate
            )
                .month
        else {
            return false
        }

        let proposedTargetMonth: Month
        let scrollPosition: CalendarViewScrollPosition
        switch (direction, content.monthsLayout) {
            case (.up, .vertical), (.right, .horizontal):
                proposedTargetMonth = Month(
                    era: lastVisibleMonth.era,
                    year: lastVisibleMonth.year,
                    month: lastVisibleMonth.month - numberOfVisibleMonths,
                    isInGregorianCalendar: lastVisibleMonth.isInGregorianCalendar
                )
                scrollPosition = .lastFullyVisiblePosition

            case (.down, .vertical), (.left, .horizontal):
                proposedTargetMonth = Month(
                    era: firstVisibleMonth.era,
                    year: firstVisibleMonth.year,
                    month: firstVisibleMonth.month + numberOfVisibleMonths,
                    isInGregorianCalendar: firstVisibleMonth.isInGregorianCalendar
                )
                scrollPosition = .firstFullyVisiblePosition

            default:
                return false
        }

        let firstMonth = content.monthRange.lowerBound
        let lastMonth = content.monthRange.upperBound
        let targetMonth = max(firstMonth, min(lastMonth, proposedTargetMonth))
        guard let targetMonthDate = calendar.date(from: targetMonth.components) else { return false }

        scroll(toMonthContaining: targetMonthDate, scrollPosition: scrollPosition, animated: false)

        let targetMonthItem = content.monthHeaderItemProvider(targetMonth)
        let targetMonthView = targetMonthItem._makeView()
        targetMonthItem._setContent(onViewOfSameType: targetMonthView)
        let accessibilityScrollText = targetMonthView.accessibilityLabel
        UIAccessibility.post(notification: .pageScrolled, argument: accessibilityScrollText)

        // ensure that scrolling related callbacks are still fired when performing scrolling via accessibility
        if let visibleDayRange {
            didScroll?(visibleDayRange, false)
            didEndDragging?(visibleDayRange, true)
            didEndDecelerating?(visibleDayRange)
        }

        return true
    }

    // MARK: Package-private

    @objc
    func accessibilityElementFocused(_ notification: NSNotification) {
        guard
            let element = notification.userInfo?[UIAccessibility.focusedElementUserInfoKey] as? UIResponder,
            let itemView = element.nextItemView()
        else {
            return
        }

        initialItemViewWasFocused = true

        // If the accessibility element is not fully in view, programmatically scroll it to be centered.
        let isElementFullyVisible: Bool
        let viewFrameInCalendarView = itemView.convert(itemView.bounds, to: self)
        switch scrollMetricsMutator.scrollAxis {
            case .vertical:
                let verticalBounds = CGRect(
                    x: 0,
                    y: layoutMargins.top,
                    width: bounds.width,
                    height: bounds.height - layoutMargins.top - layoutMargins.bottom
                )
                isElementFullyVisible = verticalBounds.contains(viewFrameInCalendarView)
            case .horizontal:
                let horizontalBounds = CGRect(
                    x: layoutMargins.left,
                    y: 0,
                    width: bounds.width - layoutMargins.left - layoutMargins.right,
                    height: bounds.height
                )
                isElementFullyVisible = horizontalBounds.contains(viewFrameInCalendarView)
        }

        if
            !isElementFullyVisible,
            let itemType = itemView.itemType,
            case let .layoutItemType(layoutItemType) = itemType
        {
            switch layoutItemType {
                case let .monthHeader(month):
                    let dateInTargetMonth = calendar.firstDate(of: month)
                    scroll(toMonthContaining: dateInTargetMonth, scrollPosition: .centered, animated: false)
                case let .day(day):
                    let dateInTargetDay = calendar.startDate(of: day)
                    scroll(toDayContaining: dateInTargetDay, scrollPosition: .centered, animated: false)
                default:
                    break
            }
        }
    }
}
