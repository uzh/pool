const frameClass = "print-frame";

export const initPrint = () => {
    document.querySelectorAll("[data-print]").forEach((element) => {
        element.addEventListener("click", (ev) => {
            ev.preventDefault();

            const body = document.querySelector("body");
            const currentUrl = window.location.href;
            const printUrl = `${currentUrl}/print`
            const printFrame = document.createElement("iframe");

            printFrame.src = printUrl;
            printFrame.style.visibility = "hidden";
            printFrame.style.height = "0";
            printFrame.style.overflow = "hidden";
            printFrame.classList.add(frameClass);

            body.appendChild(printFrame);
            printFrame.contentWindow.print();
        })
    })
}


// TODO: Figure out how to remove iframe after print

// window.addEventListener("afterprint", (e) => {
//     const elms = document.querySelectorAll(`.${frameClass}`);
// });

            // window.addEventListener("afterprint", (e) => {
            //     console.log('frame in event event: ', printFrame);
            // }, { once: true });
