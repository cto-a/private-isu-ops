package score

import "fmt"

type ScoreRepositoryImple struct{}

func (r *ScoreRepositoryImple) SaveScore(score *Score) error {
	fmt.Println("not implements Score: ", score)
	return nil
}
