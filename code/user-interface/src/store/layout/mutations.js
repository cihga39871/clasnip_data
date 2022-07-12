
function activateLink (state, routePath) {
  state.analysisLinks.forEach(element => {
    element.isActive = routePath.startsWith(element.link)
  })
  state.settingLinks.forEach(element => {
    element.isActive = routePath.startsWith(element.link)
  })
  state.userLinks.forEach(element => {
    element.isActive = routePath.startsWith(element.link)
  })
}

function userLinks (state) {
  state.analysisLinks.forEach(element => {
    element.isHidden = false
  })
  state.settingLinks.forEach(element => {
    element.isHidden = true
  })
  state.userLinks[0].isHidden = false
  state.userLinks[1].isHidden = true
  state.userLinks[2].isHidden = false
  state.userLinks[3].isHidden = true
}

function guestLinks (state) {
  state.analysisLinks.forEach(element => {
    element.isHidden = false
  })
  state.settingLinks.forEach(element => {
    element.isHidden = true
  })
  state.userLinks[0].isHidden = true
  state.userLinks[1].isHidden = false
  state.userLinks[2].isHidden = true
  state.userLinks[3].isHidden = false
}

export { activateLink, userLinks, guestLinks }
