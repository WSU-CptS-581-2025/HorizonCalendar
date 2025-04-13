//
//  CalendarViewUserInteraction.swift
//  HorizonCalendar
//
//  Created by Kyle Parker on 4/13/25.
//  Copyright © 2025 Airbnb. All rights reserved.
//

import UIKit

// MARK: - Calendar View Scroll Extension

public extension CalendarView {
    // MARK: Public

    /// Scrolls the calendar to the specified month with the specified position.
    ///
    /// If the calendar has a non-zero frame, this function will scroll to the specified month immediately. Otherwise the scroll-to-month
    /// action will be queued and executed once the calendar has a non-zero frame. If this function is invoked multiple times before the
    /// calendar has a non-zero frame, only the most recent scroll-to-month action will be executed.
    ///
    /// - Parameters:
    ///   - dateInTargetMonth: A date in the target month to which to scroll into view.
    ///   - scrollPosition: The final position of the `CalendarView`'s scrollable region after the scroll completes.
    ///   - animated: Whether the scroll should be animated (from the current position), or whether the scroll should update the
    ///   visible region immediately with no animation.
    func scroll(
        toMonthContaining dateInTargetMonth: Date,
        scrollPosition: CalendarViewScrollPosition,
        animated: Bool
    ) {
        let month = calendar.month(containing: dateInTargetMonth)
        guard content.monthRange.contains(month) else {
            assertionFailure("""
              Attempted to scroll to month \(month), which is out of bounds of the total date range
              \(content.monthRange).
            """)
            return
        }

        // Cancel in-flight scroll
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)

        scrollToItemContext = ScrollToItemContext(
            targetItem: .month(month),
            scrollPosition: scrollPosition,
            animated: animated
        )

        if animated {
            startScrollingTowardTargetItem()
        } else {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    /// Scrolls the calendar to the specified day with the specified position.
    ///
    /// If the calendar has a non-zero frame, this function will scroll to the specified day immediately. Otherwise the scroll-to-day action
    /// will be queued and executed once the calendar has a non-zero frame. If this function is invoked multiple times before the calendar
    /// has a non-zero frame, only the most recent scroll-to-day action will be executed.
    ///
    /// - Parameters:
    ///   - dateInTargetDay: A date in the target day to which to scroll into view.
    ///   - scrollPosition: The final position of the `CalendarView`'s scrollable region after the scroll completes.
    ///   - animated: Whether the scroll should be animated (from the current position), or whether the scroll should update the
    ///   visible region immediately with no animation.
    func scroll(
        toDayContaining dateInTargetDay: Date,
        scrollPosition: CalendarViewScrollPosition,
        animated: Bool
    ) {
        let day = calendar.day(containing: dateInTargetDay)
        guard content.dayRange.contains(day) else {
            assertionFailure("""
              Attempted to scroll to day \(day), which is out of bounds of the total date range
              \(content.dayRange).
            """)
            return
        }

        // Cancel in-flight scroll
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)

        scrollToItemContext = ScrollToItemContext(
            targetItem: .day(day),
            scrollPosition: scrollPosition,
            animated: animated
        )

        if animated {
            startScrollingTowardTargetItem()
        } else {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    func updateAutoScrollingState(gestureRecognizer: UIGestureRecognizer) {
        func enableAutoScroll(offset: CGFloat) {
            autoScrollOffset = offset

            if autoScrollDisplayLink == nil {
                let autoScrollDisplayLink = CADisplayLink(
                    target: self,
                    selector: #selector(autoScrollDisplayLinkFired)
                )
                autoScrollDisplayLink.add(to: .main, forMode: .common)
                self.autoScrollDisplayLink = autoScrollDisplayLink
            }
        }

        func disableAutoScroll() {
            autoScrollDisplayLink?.invalidate()
            autoScrollOffset = nil
        }

        switch gestureRecognizer.state {
        case .changed:
            let edgeMargin: CGFloat = 32
            let offset: CGFloat = 6
            let locationInCalendarView = gestureRecognizer.location(in: self)
            switch content.monthsLayout {
            case .vertical:
                if locationInCalendarView.y < layoutMargins.top + edgeMargin {
                    enableAutoScroll(offset: -offset)
                } else if locationInCalendarView.y > bounds.height - layoutMargins.bottom - edgeMargin {
                    enableAutoScroll(offset: offset)
                } else {
                    disableAutoScroll()
                }

            case .horizontal:
                if locationInCalendarView.x < layoutMargins.left + edgeMargin {
                    enableAutoScroll(offset: -offset)
                } else if locationInCalendarView.x > bounds.width - layoutMargins.right - edgeMargin {
                    enableAutoScroll(offset: offset)
                } else {
                    disableAutoScroll()
                }
            }

        default:
            disableAutoScroll()
        }
    }

    private func startScrollingTowardTargetItem() {
        let scrollToItemDisplayLink = CADisplayLink(
            target: self,
            selector: #selector(scrollToItemDisplayLinkFired)
        )

        scrollToItemAnimationStartTime = CACurrentMediaTime()

        if #available(iOS 15.0, *) {
            #if swift(>=5.5) // Allows us to still build using Xcode 12
                scrollToItemDisplayLink.preferredFrameRateRange = CAFrameRateRange(
                    minimum: 80,
                    maximum: 120,
                    preferred: 120
                )
            #endif
        }

        scrollToItemDisplayLink.add(to: .main, forMode: .common)
        self.scrollToItemDisplayLink = scrollToItemDisplayLink
    }

    private func finalizeScrollingTowardItem(for scrollToItemContext: ScrollToItemContext) {
        self.scrollToItemContext = ScrollToItemContext(
            targetItem: scrollToItemContext.targetItem,
            scrollPosition: scrollToItemContext.scrollPosition,
            animated: false
        )
    }

    @objc
    private func scrollToItemDisplayLinkFired() {
        guard
            let scrollToItemContext,
            let animationStartTime = scrollToItemAnimationStartTime
        else {
            preconditionFailure("""
              Expected `scrollToItemContext`, `animationStartTime`, and `scrollMetricsMutator` to be
              non-nil when animating toward an item.
            """)
        }

        guard scrollToItemContext.animated else {
            preconditionFailure(
                "The scroll-to-item animation display link fired despite no animation being needed.")
        }

        guard isReadyForLayout else { return }

        let positionBeforeLayout = positionRelativeToVisibleBounds(for: scrollToItemContext.targetItem)

        let secondsSinceAnimationStart = CACurrentMediaTime() - animationStartTime
        let offset = maximumPerAnimationTickOffset * CGFloat(min(secondsSinceAnimationStart / 5, 1))
        switch positionBeforeLayout {
        case .before:
            scrollMetricsMutator.applyOffset(CGFloat(-offset))

        case .after:
            scrollMetricsMutator.applyOffset(offset)

        case let .partiallyOrFullyVisible(frame):
            let targetPosition: CGFloat
            let currentPosition: CGFloat
            switch content.monthsLayout {
            case .vertical:
                targetPosition = anchorLayoutItem(
                    for: scrollToItemContext,
                    visibleItemsProvider: visibleItemsProvider
                )
                .frame.minY
                currentPosition = frame.minY
            case .horizontal:
                targetPosition = anchorLayoutItem(
                    for: scrollToItemContext,
                    visibleItemsProvider: visibleItemsProvider
                )
                .frame.minX
                currentPosition = frame.minX
            }
            let distanceToTargetPosition = currentPosition - targetPosition
            if distanceToTargetPosition <= -1 {
                scrollMetricsMutator.applyOffset(max(CGFloat(-offset), distanceToTargetPosition))
            } else if distanceToTargetPosition >= 1 {
                scrollMetricsMutator.applyOffset(min(offset, distanceToTargetPosition))
            } else {
                finalizeScrollingTowardItem(for: scrollToItemContext)
            }

        case .none:
            break
        }

        setNeedsLayout()
        layoutIfNeeded()

        // If we overshoot our target item, then finalize the animation immediately. In practice, this
        // will only happen if the maximum per-animation-tick offset is greater than the viewport size.
        let positionAfterLayout = positionRelativeToVisibleBounds(for: scrollToItemContext.targetItem)
        switch (positionBeforeLayout, positionAfterLayout) {
        case (.before, .after), (.after, .before):
            finalizeScrollingTowardItem(for: scrollToItemContext)

            // Force layout immediately to prevent the overshoot from being visible to the user.
            setNeedsLayout()
            layoutIfNeeded()

        default:
            break
        }
    }
}

// MARK: - ScrollViewDelegate

/// Rather than making `CalendarView` conform to `UIScrollViewDelegate`, which would expose those methods as public, we
/// use a separate delegate object to hide these methods from the public API.
final class ScrollViewDelegate: NSObject, UIScrollViewDelegate {
    // MARK: Lifecycle

    init(calendarView: CalendarView) {
        self.calendarView = calendarView
    }

    // MARK: Internal

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let calendarView else { return }

        calendarView.preventLargeOverScrollIfNeeded()

        let isUserInitiatedScrolling = scrollView.isDragging && scrollView.isTracking

        if let visibleDayRange = calendarView.visibleDayRange {
            calendarView.didScroll?(visibleDayRange, isUserInitiatedScrolling)
        }

        if isUserInitiatedScrolling {
            // If the user interacts with the scroll view, we should clear out any existing
            // `scrollToItemContext` that might be leftover from the initial layout process.
            calendarView.scrollToItemContext = nil
        }

        calendarView.setNeedsLayout()
    }

    func scrollViewDidEndDragging(
        _: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        guard let calendarView, let visibleDayRange = calendarView.visibleDayRange else { return }
        calendarView.didEndDragging?(visibleDayRange, decelerate)
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        guard let calendarView, let visibleDayRange = calendarView.visibleDayRange else { return }
        calendarView.didEndDecelerating?(visibleDayRange)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard
            let calendarView,
            case let .horizontal(options) = calendarView.content.monthsLayout,
            case .paginatedScrolling = options.scrollingBehavior
        else {
            return
        }

        let pageSize = options.pageSize(
            calendarWidth: calendarView.bounds.width,
            interMonthSpacing: calendarView.content.interMonthSpacing
        )
        calendarView.previousPageIndex = PaginationHelpers.closestPageIndex(
            forOffset: scrollView.contentOffset.x,
            pageSize: pageSize
        )
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard
            let calendarView,
            case let .horizontal(options) = calendarView.content.monthsLayout,
            case let .paginatedScrolling(paginationConfiguration) = options.scrollingBehavior
        else {
            return
        }

        let pageSize = options.pageSize(
            calendarWidth: calendarView.bounds.width,
            interMonthSpacing: calendarView.content.interMonthSpacing
        )

        switch paginationConfiguration.restingAffinity {
        case .atPositionsAdjacentToPrevious:
            guard let previousPageIndex = calendarView.previousPageIndex else {
                preconditionFailure("""
                  `previousPageIndex` was accessed before being set in `scrollViewWillBeginDragging`.
                """)
            }
            targetContentOffset.pointee.x = PaginationHelpers.adjacentPageOffset(
                toPreviousPageIndex: previousPageIndex,
                targetOffset: targetContentOffset.pointee.x,
                velocity: velocity.x,
                pageSize: pageSize
            )

        case .atPositionsClosestToTargetOffset:
            targetContentOffset.pointee.x = PaginationHelpers.closestPageOffset(
                toTargetOffset: targetContentOffset.pointee.x,
                touchUpOffset: scrollView.contentOffset.x,
                velocity: velocity.x,
                pageSize: pageSize
            )
        }
    }

    func scrollViewShouldScrollToTop(_: UIScrollView) -> Bool {
        guard let calendarView else { return false }

        if calendarView.content.monthsLayout.scrollsToFirstMonthOnStatusBarTap {
            let firstMonth = calendarView.content.monthRange.lowerBound
            let firstDate = calendarView.calendar.firstDate(of: firstMonth)
            calendarView.scroll(
                toMonthContaining: firstDate,
                scrollPosition: .firstFullyVisiblePosition(padding: 0),
                animated: true
            )
        }

        return false
    }

    // MARK: Private

    private weak var calendarView: CalendarView?
}

// MARK: - GestureRecognizerDelegate

/// Rather than making `CalendarView` conform to `UIGestureRecognizerDelegate`, which would expose those methods as
/// public, we use a separate delegate object to hide these methods from the public API.
final class GestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    // MARK: Lifecycle

    init(calendarView: CalendarView) {
        self.calendarView = calendarView
    }

    // MARK: Internal

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    )
        -> Bool
    {
        guard let calendarView else { return false }

        let isGestureRecognizerMultiSelectGesture =
            gestureRecognizer === calendarView.multiDaySelectionLongPressGestureRecognizer ||
            gestureRecognizer === calendarView.multiDaySelectionPanGestureRecognizer
        let isOtherGestureRecognizerScrollViewPanGesture =
            otherGestureRecognizer === calendarView.scrollView.panGestureRecognizer
        let isMultiSelectingAndScrolling =
            isGestureRecognizerMultiSelectGesture &&
            isOtherGestureRecognizerScrollViewPanGesture &&
            gestureRecognizer.state == .changed
        return isMultiSelectingAndScrolling
    }

    // MARK: Private

    private weak var calendarView: CalendarView?
}

// MARK: Scroll View Silent Updating

extension UIScrollView {
    func performWithoutNotifyingDelegate(_ operations: () -> Void) {
        let delegate = delegate
        self.delegate = nil

        operations()

        self.delegate = delegate
    }
}
