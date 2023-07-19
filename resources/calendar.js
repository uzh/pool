import { Calendar } from '@fullcalendar/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import listPlugin from '@fullcalendar/list';
import tippy from 'tippy.js';
import 'tippy.js/dist/tippy.css'; // optional for styling

import { notifyUser } from "./admin/utils"

const notificationId = "calendar-notification";

const viewBreakpoint = 765
const maxHeight = 800

const normalizeSession = (session) => {
    session.end = session.end_
    delete session.end_
    return session
}

const determineView = () => window.innerWidth >= viewBreakpoint ? "dayGridMonth" : "listWeek";

const tooltipContent = ({ _instance, _def }, calendarType) => {
    const showLocation = calendarType != "location";
    const { start, end } = _instance.range;
    const toLocalTime = date => date.toLocaleTimeString('en',
        { timeStyle: 'short', hour12: false, timeZone: 'Europe/Zurich' })
    const { title, extendedProps } = _def;
    const contactPerson = extendedProps.contact_person

    const { assignment_count, max_participants, min_participants, overbook } = extendedProps;
    const counterHtml = `<p><strong>Participants: ${assignment_count} / ${max_participants}</strong><br>Overbook: ${overbook}<br>Min. participants: ${min_participants}</p>`

    const contactPersonHtml = contactPerson ? `<a href="mailto:${contactPerson.email}">${contactPerson.name}</a><br>` : ''
    const header = `<div class="card-header">${title}</div>`
    const body = `<div class="card-body">
        <p>${showLocation ? `${extendedProps.location.name}<br>` : ""}
            ${toLocalTime(start)} - ${toLocalTime(end)}
        </p><br>
        ${extendedProps.description ? `${extendedProps.description}<br>` : ""}
        ${contactPersonHtml}
        ${counterHtml}
        </div>`
    return `<div class="card fc-tooltip">${header}${body}</div>`
}

export const initCalendar = () => {
    document.querySelectorAll("[data-calendar]").forEach(el => {
        try {
            const { calendar: calendarType, location } = el.dataset
            let url;
            switch (calendarType) {
                case "location":
                    if (location) {
                        url = `/admin/sessions/location/${location}`
                    } else {
                        throw "Location id missing."
                    }
                    break;
                case "user":
                    url = "/admin/sessions"
                    break;
                default:
                    throw "Calendar type missing."
            }

            new Calendar(el, {
                plugins: [dayGridPlugin, timeGridPlugin, listPlugin],
                timeZone: 'Europe/Zurich',
                initialView: 'dayGridMonth',
                firstDay: 1,
                height: maxHeight,
                headerToolbar: {
                    left: 'prev,next today',
                    center: 'title',
                    right: 'dayGridMonth,timeGridWeek,listWeek'
                },
                eventTimeFormat: {
                    hour: "numeric",
                    minute: "2-digit",
                    meridiem: false,
                    hour12: false,
                },
                eventDidMount: function (info) {
                    tippy(info.el, {
                        content: tooltipContent(info.event, calendarType),
                        allowHTML: true,
                        placement: 'right',
                    });
                },
                eventSources: [{
                    url: url,
                    success: e => e.map(e => normalizeSession(e)),
                    failure: e => { notifyUser(notificationId, "error", e) }
                }],
                initialView: determineView(),
                windowResize: function () {
                    this.changeView(determineView())
                },
            }).render();
        } catch (error) {
            console.error(error)
        }
    })
}
